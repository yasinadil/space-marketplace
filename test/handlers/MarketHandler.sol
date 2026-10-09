// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SpaceMarketplace} from "../../contracts/SpaceMarketplace.sol";
import {MockWETH} from "../mocks/MockWETH.sol";

/// @notice Drives random but valid sequences of marketplace actions for invariant testing.
///         Only a handful of spaces are used so actions collide often.
contract MarketHandler is Test {
    SpaceMarketplace internal market;
    MockWETH internal weth;
    address internal admin;

    address[] internal actors;
    uint256 internal constant SPACES = 5;

    constructor(SpaceMarketplace _market, MockWETH _weth, address _admin) {
        market = _market;
        weth = _weth;
        admin = _admin;
        for (uint256 i; i < 4; i++) {
            address a = makeAddr(string(abi.encodePacked("actor", vm.toString(i))));
            weth.mint(a, 1_000_000 ether);
            vm.prank(a);
            weth.approve(address(market), type(uint256).max);
            actors.push(a);
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _id(uint256 seed) internal pure returns (uint256) {
        return (seed % SPACES) + 1;
    }

    function _owner(uint256 id) internal view returns (address o) {
        (,, o,,,,,,,) = market.spaces(id);
    }

    function _topOfferer(uint256 id) internal view returns (address o) {
        (,,,,, o,,,,) = market.spaces(id);
    }

    function _topOffer(uint256 id) internal view returns (uint256 v) {
        (,,,, v,,,,,) = market.spaces(id);
    }

    function claimSpace(uint256 actorSeed, uint256 idSeed, uint256 amount) external {
        uint256 id = _id(idSeed);
        if (_owner(id) != address(0)) return;
        vm.prank(_actor(actorSeed));
        market.claimSpace(id, bound(amount, 0, 1_000 ether));
    }

    function deposit(uint256 idSeed, uint256 amount) external {
        uint256 id = _id(idSeed);
        address o = _owner(id);
        if (o == address(0)) return;
        amount = bound(amount, market.MIN_DEPOSIT(), 1_000 ether);
        vm.prank(o);
        market.deposit(id, amount);
    }

    function withdraw(uint256 idSeed, uint256 amount) external {
        uint256 id = _id(idSeed);
        address o = _owner(id);
        if (o == address(0)) return;
        uint256 remaining = market.getRemainingBalance(id);
        vm.prank(o);
        market.withdraw(id, bound(amount, 0, remaining));
    }

    function offer(uint256 actorSeed, uint256 idSeed, uint256 amount, uint256 escrow) external {
        uint256 id = _id(idSeed);
        address o = _owner(id);
        address bidder = _actor(actorSeed);
        if (o == address(0) || o == bidder) return;
        uint256 top = _topOffer(id);
        if (top >= 10_000 ether) return;
        vm.prank(bidder);
        market.offer(id, bound(amount, top + 1, 10_000 ether), bound(escrow, 0, 1_000 ether));
    }

    function retractOffer(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        address bidder = _topOfferer(id);
        if (bidder == address(0)) return;
        vm.prank(bidder);
        market.retractOffer(id);
    }

    function acceptOffer(uint256 actorSeed, uint256 idSeed, bool asOwner) external {
        uint256 id = _id(idSeed);
        address o = _owner(id);
        if (o == address(0) || _topOfferer(id) == address(0)) return;
        address caller = asOwner ? o : _actor(actorSeed);
        if (caller != o && market.getRemainingBalance(id) > 0) return; // owner still defends
        vm.prank(caller);
        market.acceptOffer(id);
    }

    function transferSpace(uint256 actorSeed, uint256 idSeed) external {
        uint256 id = _id(idSeed);
        address o = _owner(id);
        if (o == address(0)) return;
        vm.prank(o);
        market.transferSpace(id, _actor(actorSeed));
    }

    function claimRevenue() external {
        vm.prank(admin);
        market.claimRevenue();
    }

    function warp(uint256 secs) external {
        skip(bound(secs, 1, 400 days));
    }
}
