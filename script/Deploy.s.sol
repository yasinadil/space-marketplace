// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SpaceMarketplace} from "../contracts/SpaceMarketplace.sol";

/// Usage:
///   WETH=<weth address> forge script script/Deploy.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast --verify
contract Deploy is Script {
    function run() external returns (SpaceMarketplace market) {
        IERC20 weth = IERC20(vm.envAddress("WETH"));
        vm.startBroadcast();
        market = new SpaceMarketplace(weth);
        vm.stopBroadcast();
        console2.log("SpaceMarketplace deployed at", address(market));
    }
}
