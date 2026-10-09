// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {SpaceMarketplace} from "../contracts/SpaceMarketplace.sol";
import {MockNFT} from "./mocks/MockNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SpaceMarketplaceTest is Base {
    // ---------------------------------------------------------------- claim

    function test_claimSpace() public {
        vm.prank(alice);
        market.claimSpace(1, 5 ether);

        (address owner, uint256 balance,,,) = _space(1);
        assertEq(owner, alice);
        assertEq(balance, 5 ether);
        assertEq(weth.balanceOf(address(market)), 5 ether);
    }

    function test_claimSpace_revertsOnInvalidOrTaken() public {
        vm.startPrank(alice);
        vm.expectRevert(SpaceMarketplace.InvalidSpace.selector);
        market.claimSpace(0, 1 ether);
        vm.expectRevert(SpaceMarketplace.InvalidSpace.selector);
        market.claimSpace(101, 1 ether);
        market.claimSpace(1, 1 ether);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(SpaceMarketplace.SpaceAlreadyClaimed.selector);
        market.claimSpace(1, 1 ether);
    }

    // ---------------------------------------------------------------- streaming

    function test_noOffer_meansNoStream() public {
        vm.prank(alice);
        market.claimSpace(1, 5 ether);
        skip(10 * YEAR);
        assertEq(market.getRemainingBalance(1), 5 ether);
    }

    function test_streamsTenPercentOfTopOfferPerYear() public {
        vm.prank(alice);
        market.claimSpace(1, 5 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 2 ether);

        skip(YEAR);
        // 10% of 10 ETH over a year = 1 ETH (minus per-second rounding)
        assertApproxEqAbs(market.getRemainingBalance(1), 4 ether, 1e8);
        assertApproxEqAbs(market.getSubscriptionRevenue(), 1 ether, 1e8);
    }

    function test_streamCapsAtBalance() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);

        skip(5 * YEAR);
        assertEq(market.getRemainingBalance(1), 0);
        assertEq(market.getSubscriptionRevenue(), 1 ether);
    }

    // ---------------------------------------------------------------- deposit / withdraw

    function test_depositIntoDepletedSpace_keepsDeposit() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(5 * YEAR); // fully depleted

        vm.prank(alice);
        market.deposit(1, 3 ether);
        assertEq(market.getRemainingBalance(1), 3 ether);
        assertEq(market.receiverBal(), 1 ether);
    }

    function test_withdraw_chargesElapsedStreamOnce() public {
        vm.prank(alice);
        market.claimSpace(1, 10 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(YEAR / 2);

        uint256 remaining = market.getRemainingBalance(1);
        vm.prank(alice);
        market.withdraw(1, 1 ether);
        assertEq(market.getRemainingBalance(1), remaining - 1 ether);
    }

    function test_withdraw_onlyOwnerAndBounded() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);

        vm.prank(bob);
        vm.expectRevert(SpaceMarketplace.NotSpaceOwner.selector);
        market.withdraw(1, 1);

        vm.prank(alice);
        vm.expectRevert(SpaceMarketplace.InsufficientBalance.selector);
        market.withdraw(1, 2 ether);
    }

    function test_deposit_revertsBelowMinimum() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(alice);
        vm.expectRevert(SpaceMarketplace.AmountTooLow.selector);
        market.deposit(1, 1);
    }

    // ---------------------------------------------------------------- offers

    function test_outbidRefundsPreviousBidder() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);

        uint256 bobBefore = weth.balanceOf(bob);
        vm.prank(bob);
        market.offer(1, 2 ether, 1 ether);
        vm.prank(carol);
        market.offer(1, 3 ether, 1 ether);

        assertEq(weth.balanceOf(bob), bobBefore, "bob fully refunded");
        (,,, address top,) = _space(1);
        assertEq(top, carol);
    }

    function test_offer_mustBeatTopAndNotOwner() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);

        vm.prank(alice);
        vm.expectRevert(SpaceMarketplace.OwnerCannotOffer.selector);
        market.offer(1, 1 ether, 0);

        vm.prank(bob);
        market.offer(1, 2 ether, 0);
        vm.prank(carol);
        vm.expectRevert(SpaceMarketplace.OfferTooLow.selector);
        market.offer(1, 2 ether, 0);
    }

    function test_retractOffer() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        uint256 bobBefore = weth.balanceOf(bob);
        vm.prank(bob);
        market.offer(1, 2 ether, 1 ether);

        vm.prank(carol);
        vm.expectRevert(SpaceMarketplace.NotHighestOfferer.selector);
        market.retractOffer(1);

        vm.prank(bob);
        market.retractOffer(1);
        assertEq(weth.balanceOf(bob), bobBefore);
    }

    // ---------------------------------------------------------------- acceptance & foreclosure

    function test_ownerAcceptsOffer() public {
        vm.prank(alice);
        market.claimSpace(1, 4 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 2 ether);
        skip(YEAR);

        uint256 remaining = market.getRemainingBalance(1);
        uint256 aliceBefore = weth.balanceOf(alice);
        vm.prank(alice);
        market.acceptOffer(1);

        (address owner, uint256 balance, uint256 top,,) = _space(1);
        assertEq(owner, bob);
        assertEq(balance, 2 ether, "bidder escrow becomes balance");
        assertEq(top, 0);
        assertEq(
            weth.balanceOf(alice), aliceBefore + 10 ether + remaining, "price + unspent balance"
        );
    }

    function test_strangerCannotAcceptWhileOwnerFunded() public {
        vm.prank(alice);
        market.claimSpace(1, 4 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 2 ether);

        vm.prank(carol);
        vm.expectRevert(SpaceMarketplace.OwnerDefended.selector);
        market.acceptOffer(1);
    }

    function test_foreclosureOnceBalanceExhausted() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 2 ether);
        skip(2 * YEAR);

        vm.prank(carol); // anyone
        market.acceptOffer(1);
        (address owner,,,,) = _space(1);
        assertEq(owner, bob);
    }

    function test_acceptOffer_revertsWithoutOffer() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(alice);
        vm.expectRevert(SpaceMarketplace.NoOffer.selector);
        market.acceptOffer(1);
    }

    // ---------------------------------------------------------------- transfer

    function test_transferToTopBidderRefundsTheirOffer() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        uint256 bobBefore = weth.balanceOf(bob);
        vm.prank(bob);
        market.offer(1, 2 ether, 1 ether);

        vm.prank(alice);
        market.transferSpace(1, bob);

        (address owner,,, address top,) = _space(1);
        assertEq(owner, bob);
        assertEq(top, address(0));
        assertEq(weth.balanceOf(bob), bobBefore);
    }

    function test_transferSpace_rejectsZeroAddress() public {
        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        vm.prank(alice);
        vm.expectRevert(SpaceMarketplace.ZeroAddress.selector);
        market.transferSpace(1, address(0));
    }

    // ---------------------------------------------------------------- revenue

    function test_claimRevenue_cannotBeRepeated() public {
        vm.prank(alice);
        market.claimSpace(1, 5 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(YEAR);

        vm.startPrank(admin);
        market.claimRevenue();
        uint256 afterFirst = weth.balanceOf(admin);
        market.claimRevenue();
        vm.stopPrank();

        assertApproxEqAbs(afterFirst, 1 ether, 1e8);
        assertEq(weth.balanceOf(admin), afterFirst, "second claim pays nothing");
    }

    function test_claimRevenue_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        market.claimRevenue();
    }

    function test_setReceiver_settlesThenRedirects() public {
        vm.prank(alice);
        market.claimSpace(1, 5 ether);
        vm.prank(bob);
        market.offer(1, 10 ether, 0);
        skip(YEAR);

        vm.prank(admin);
        vm.expectRevert(SpaceMarketplace.ZeroAddress.selector);
        market.setReceiver(address(0));

        vm.startPrank(admin);
        market.setReceiver(carol);
        uint256 carolBefore = weth.balanceOf(carol);
        market.claimRevenue();
        vm.stopPrank();
        assertApproxEqAbs(weth.balanceOf(carol) - carolBefore, 1 ether, 1e8);
    }

    // ---------------------------------------------------------------- guards & views

    function test_constructor_rejectsZeroWeth() public {
        vm.expectRevert(SpaceMarketplace.ZeroAddress.selector);
        new SpaceMarketplace(IERC20(address(0)));
    }

    function test_unclaimedSpaceGuards() public {
        vm.startPrank(alice);
        vm.expectRevert(SpaceMarketplace.SpaceNotFound.selector);
        market.deposit(2, 1 ether);
        vm.expectRevert(SpaceMarketplace.SpaceNotFound.selector);
        market.offer(2, 1 ether, 0);
        vm.expectRevert(SpaceMarketplace.SpaceNotFound.selector);
        market.acceptOffer(2);
        vm.stopPrank();
    }

    function test_viewsCoverAllSpaces() public {
        vm.prank(alice);
        market.claimSpace(3, 2 ether);
        vm.prank(bob);
        market.offer(3, 10 ether, 0);
        skip(YEAR);

        SpaceMarketplace.Space[] memory all = market.getAllSpaces();
        uint256[] memory balances = market.getCurrentRemainingBalances();
        assertEq(all.length, 100);
        assertEq(all[2].owner, alice);
        assertEq(balances[2], market.getRemainingBalance(3));
        assertEq(balances[0], 0);
    }

    // ---------------------------------------------------------------- metadata

    function test_setSpaceUri_requiresNftOwnership() public {
        MockNFT nft = new MockNFT();
        nft.mint(alice, 7);
        vm.prank(alice);
        market.claimSpace(1, 1 ether);

        vm.prank(alice);
        market.setSpaceUri(1, 7, address(nft));
        assertEq(market.getNftUri(1), "ipfs://badge/7");

        nft.mint(bob, 8);
        vm.prank(alice);
        vm.expectRevert(SpaceMarketplace.NotNftOwner.selector);
        market.setSpaceUri(1, 8, address(nft));
    }

    // ---------------------------------------------------------------- fuzz

    /// Remaining balance + streamed revenue always equals what was deposited.
    function testFuzz_streamConservesValue(uint96 deposit, uint96 bid, uint32 elapsed) public {
        deposit = uint96(bound(deposit, 1, 100_000 ether));
        bid = uint96(bound(bid, 1, 100_000 ether));

        vm.prank(alice);
        market.claimSpace(1, deposit);
        vm.prank(bob);
        market.offer(1, bid, 0);
        skip(elapsed);

        assertEq(market.getRemainingBalance(1) + market.getSubscriptionRevenue(), deposit);
    }

    /// Bidders always get exactly their escrow back when outbid.
    function testFuzz_outbidRefundIsExact(uint96 a, uint96 b, uint96 escrowA, uint32 elapsed)
        public
    {
        a = uint96(bound(a, 1, 10_000 ether));
        b = uint96(bound(b, uint256(a) + 1, 20_000 ether));
        escrowA = uint96(bound(escrowA, 0, 10_000 ether));

        vm.prank(alice);
        market.claimSpace(1, 1 ether);
        uint256 bobBefore = weth.balanceOf(bob);
        vm.prank(bob);
        market.offer(1, a, escrowA);
        skip(elapsed);
        vm.prank(carol);
        market.offer(1, b, 0);

        assertEq(weth.balanceOf(bob), bobBefore);
    }

    /// Withdraw-then-check never double-charges: the withdrawn amount is the only extra delta.
    function testFuzz_withdrawExact(uint96 deposit, uint96 bid, uint32 elapsed, uint96 amount)
        public
    {
        deposit = uint96(bound(deposit, 1 ether, 100_000 ether));
        bid = uint96(bound(bid, 1, 100_000 ether));

        vm.prank(alice);
        market.claimSpace(1, deposit);
        vm.prank(bob);
        market.offer(1, bid, 0);
        skip(elapsed);

        uint256 remaining = market.getRemainingBalance(1);
        amount = uint96(bound(amount, 0, remaining));
        vm.prank(alice);
        market.withdraw(1, amount);
        assertEq(market.getRemainingBalance(1), remaining - amount);
    }
}
