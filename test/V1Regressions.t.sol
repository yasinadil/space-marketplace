// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {SpaceMarketPlaceV1} from "../contracts/legacy/SpaceMarketplaceV1.sol";

/// @notice Each test reproduces a v1 bug, then runs the identical scenario against v2.
///         `v1` is the original contract; `market` (from Base) is v2.
contract V1RegressionsTest is Base {
    SpaceMarketPlaceV1 internal v1;
    uint256 internal constant DUST = 1e8; // per-second rounding of the stream rate

    function setUp() public override {
        super.setUp();
        v1 = new SpaceMarketPlaceV1(weth); // this test contract is v1's owner and receiver
        for (uint256 i; i < 3; i++) {
            address who = [alice, bob, carol][i];
            vm.prank(who);
            weth.approve(address(v1), type(uint256).max);
        }
    }

    /// Bug 1 — `offer()` overwrote `highestOfferer` before refunding, so the outbid bidder's escrow
    /// went to the new bidder, who effectively bid for free.
    function test_bug1_outbidEscrowPaidToNewBidder() public {
        uint256 bob0 = weth.balanceOf(bob);
        uint256 carol0 = weth.balanceOf(carol);

        vm.prank(alice);
        v1.claimSpace(1, 1 ether);
        vm.prank(bob);
        v1.offer(1, 2 ether, 1 ether);
        vm.prank(carol);
        v1.offer(1, 3 ether, 0);

        assertEq(weth.balanceOf(bob), bob0 - 3 ether, "v1: bob's 3 WETH escrow is gone");
        assertEq(weth.balanceOf(carol), carol0, "v1: carol's 3 WETH bid cost her nothing");

        bob0 = weth.balanceOf(bob);
        carol0 = weth.balanceOf(carol);

        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(bob);
        market.offer(1, 2 ether, 1 ether);
        vm.prank(carol);
        market.offer(1, 3 ether, 0);

        assertEq(weth.balanceOf(bob), bob0, "v2: bob fully refunded");
        assertEq(weth.balanceOf(carol), carol0 - 3 ether, "v2: carol's bid is escrowed");
    }

    /// Bug 2 — `claimRevenue()` never reset `receiverBal`, so the owner could drain user funds.
    function test_bug2_revenueClaimableRepeatedly() public {
        vm.prank(alice);
        v1.claimSpace(1, 5 ether);
        vm.prank(bob);
        v1.offer(1, 10 ether, 0);
        skip(YEAR);
        v1.updateRevenue();
        uint256 accrued = v1.getSubscriptionRevenue();

        uint256 before = weth.balanceOf(address(this));
        v1.claimRevenue();
        v1.claimRevenue();
        v1.claimRevenue();
        assertEq(weth.balanceOf(address(this)) - before, 3 * accrued, "v1: paid out 3x the revenue");

        vm.prank(alice);
        market.claimSpace(1, 5 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(YEAR);
        vm.startPrank(admin);
        market.claimRevenue();
        uint256 once = weth.balanceOf(admin);
        market.claimRevenue();
        market.claimRevenue();
        vm.stopPrank();
        assertEq(weth.balanceOf(admin), once, "v2: later claims pay nothing");
    }

    /// Bug 3 — `deposit()` added funds before settling, so topping up a depleted space sent the
    /// entire top-up to the receiver.
    function test_bug3_topUpOfDepletedSpaceIsLost() public {
        vm.prank(alice);
        v1.claimSpace(1, 1 ether);
        vm.prank(bob);
        v1.offer(1, 10 ether, 0); // streams 1 WETH / year
        skip(5 * YEAR);
        vm.prank(alice);
        v1.deposit(1, 3 ether);
        assertEq(v1.getRemainingBalance(1), 0, "v1: 3 WETH top-up vanished");

        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(5 * YEAR);
        vm.prank(alice);
        market.deposit(1, 3 ether);
        assertEq(market.getRemainingBalance(1), 3 ether, "v2: top-up credited");
    }

    /// Bug 4 — `withdraw()` re-settled without advancing `subscTime`, charging the elapsed stream
    /// twice (and stranding the double-charged amount in the contract).
    function test_bug4_withdrawDoubleCharges() public {
        vm.prank(alice);
        v1.claimSpace(1, 10 ether);
        vm.prank(bob);
        v1.offer(1, 10 ether, 0);
        skip(YEAR / 2); // 0.5 WETH streamed
        vm.prank(alice);
        v1.withdraw(1, 1 ether);
        assertApproxEqAbs(v1.getRemainingBalance(1), 8 ether, DUST, "v1: 0.5 WETH charged twice");

        vm.prank(alice);
        market.claimSpace(1, 10 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(YEAR / 2);
        vm.prank(alice);
        market.withdraw(1, 1 ether);
        assertApproxEqAbs(market.getRemainingBalance(1), 8.5 ether, DUST, "v2: charged once");
    }

    /// Bug 5 — `acceptOffer()` refunded the stale (unsettled) balance, pulled the buyer's deposit
    /// from the *seller*, and left the stale stream rate running against the buyer.
    function test_bug5_acceptOfferMisaccounts() public {
        uint256 alice0 = weth.balanceOf(alice);
        vm.prank(alice);
        v1.claimSpace(1, 4 ether);
        vm.prank(bob);
        v1.offer(1, 10 ether, 2 ether); // streams 1 WETH / year
        skip(YEAR); // alice has 3 WETH left
        vm.prank(alice);
        v1.acceptOffer(1);

        // Fair outcome: alice receives price (10) + unspent balance (3) => +9 net of her 4 deposit.
        // v1: +10 price +4 stale balance -2 pulled from alice for bob's deposit => +8 net.
        assertApproxEqAbs(
            weth.balanceOf(alice), alice0 + 8 ether, DUST, "v1: seller charged buyer's deposit"
        );
        assertApproxEqAbs(
            v1.getRemainingBalance(1),
            1 ether,
            DUST,
            "v1: buyer's balance keeps burning at old rate"
        );

        alice0 = weth.balanceOf(alice);
        vm.prank(alice);
        market.claimSpace(1, 4 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 2 ether);
        skip(YEAR);
        vm.prank(alice);
        market.acceptOffer(1);

        assertApproxEqAbs(
            weth.balanceOf(alice), alice0 + 9 ether, DUST, "v2: price + unspent balance"
        );
        assertEq(market.getRemainingBalance(1), 2 ether, "v2: buyer's escrow becomes their balance");
    }
}
