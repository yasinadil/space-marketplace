// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Base} from "./Base.t.sol";
import {MarketHandler} from "./handlers/MarketHandler.sol";

contract SpaceMarketplaceInvariantTest is StdInvariant, Base {
    MarketHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new MarketHandler(market, weth, admin);
        targetContract(address(handler));
    }

    /// Solvency: every wei held is owed to exactly one party — a holder, a bidder, or the receiver.
    function invariant_solvency() public view {
        uint256 owed = market.receiverBal();
        for (uint256 id = 1; id <= market.NUM_SPACES(); id++) {
            (,,, uint256 balance, uint256 highestOffer,,,,, uint256 subscOffer) = market.spaces(id);
            owed += balance + highestOffer + subscOffer;
        }
        assertEq(weth.balanceOf(address(market)), owed);
    }

    /// Lazy accrual is lossless: settled-on-read balances plus accrued revenue equal stored totals.
    function invariant_streamConservation() public view {
        uint256 stored = market.receiverBal();
        uint256 viewed = market.getSubscriptionRevenue();
        for (uint256 id = 1; id <= market.NUM_SPACES(); id++) {
            (,,, uint256 balance,,,,,,) = market.spaces(id);
            stored += balance;
            viewed += market.getRemainingBalance(id);
        }
        assertEq(viewed, stored);
    }

    /// A space's top offer is never held by its own owner.
    function invariant_ownerNeverTopBidder() public view {
        for (uint256 id = 1; id <= market.NUM_SPACES(); id++) {
            (,, address owner,,, address top,,,,) = market.spaces(id);
            if (owner != address(0)) assertTrue(owner != top);
        }
    }
}
