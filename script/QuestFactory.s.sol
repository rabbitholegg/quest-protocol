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