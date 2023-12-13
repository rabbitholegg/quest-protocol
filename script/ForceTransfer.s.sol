// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {ForceTransfer} from "../contracts/ForceTransfer.sol";

contract ForceTransferDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyAdmin
        new ForceTransfer();

        vm.stopBroadcast();
    }
}
