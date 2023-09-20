// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {QuestFactory} from "../contracts/QuestFactory.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// # To Upgrade QuestFactory.sol run this command below
// ! important: make sure storage layouts are compatible first:
// bun clean && forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract QuestFactory
// forge script script/QuestFactory.s.sol:QuestFactoryUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract QuestFactoryUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        ITransparentUpgradeableProxy questfactoryProxy = ITransparentUpgradeableProxy(C.QUEST_FACTORY_ADDRESS);

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin(C.PROXY_ADMIN_ADDRESS).upgrade(questfactoryProxy, address(new QuestFactory()));
        QuestFactory(C.QUEST_FACTORY_ADDRESS).setOwnerOnce(); // only needed once, delete after run

        vm.stopBroadcast();
    }
}

contract QuestFactoryDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        ITransparentUpgradeableProxy questfactoryProxy = ITransparentUpgradeableProxy(C.QUEST_FACTORY_ADDRESS);
        string memory json = vm.readFile("script/deployDataBytes.json");
        bytes memory ogData = vm.parseJsonBytes(json, "$.questFactoryOgImpl");
        bytes memory data = vm.parseJsonBytes(json, "$.questFactoryData");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy OgImpl
        (bool success,) = C.DETERMINISTIC_DEPLOY_PROXY.call(ogData);
        require(success, "failed to deploy OgImpl");

        // Deploy QuestFactory
        (bool success2,) = C.DETERMINISTIC_DEPLOY_PROXY.call(data);
        require(success2, "failed to deploy QuestFactory");

        // Upgrade
        ProxyAdmin(C.PROXY_ADMIN_ADDRESS).upgrade(questfactoryProxy, address(new QuestFactory()));

        // Initialize
        QuestFactory(C.QUEST_FACTORY_ADDRESS).initialize(0x94c3e5e801830dD65CD786F2fe37e79c65DF4148,0xEC3a9c7d612E0E0326e70D97c9310A5f57f9Af9E,0x0D380362762B0cf375227037f2217f59A4eC4b9E,payable(0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c),0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000,0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c,500000000000000,5000);

        vm.stopBroadcast();
    }
}