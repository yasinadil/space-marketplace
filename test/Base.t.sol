// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SpaceMarketplace} from "../contracts/SpaceMarketplace.sol";
import {MockWETH} from "./mocks/MockWETH.sol";

abstract contract Base is Test {
    SpaceMarketplace internal market;
    MockWETH internal weth;

    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant YEAR = 365 days;

    function setUp() public virtual {
        weth = new MockWETH();
        vm.prank(admin);
        market = new SpaceMarketplace(weth);
        _fund(alice);
        _fund(bob);
        _fund(carol);
    }

    function _fund(address who) internal {
        weth.mint(who, 1_000_000 ether);
        vm.prank(who);
        weth.approve(address(market), type(uint256).max);
    }

    function _space(uint256 id)
        internal
        view
        returns (
            address owner,
            uint256 balance,
            uint256 highestOffer,
            address highestOfferer,
            uint256 subscOffer
        )
    {
        (,, owner, balance, highestOffer, highestOfferer,,,, subscOffer) = market.spaces(id);
    }
}
