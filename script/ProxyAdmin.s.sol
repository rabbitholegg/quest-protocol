// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";

contract ProxyAdminDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        bytes memory data = vm.parseJsonBytes(vm.readFile("script/deployDataBytes.json"), "$.proxyAdminImpl");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyAdmin
        (bool success,) = C.DETERMINISTIC_DEPLOY_PROXY.call(data);
        require(success, "failed to deploy ProxyAdmin");

        vm.stopBroadcast();
    }
}
