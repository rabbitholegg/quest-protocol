// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {QuestFactory} from "../contracts/QuestFactory.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// # To Upgrade QuestFactory.sol run this command below
// ! important: make sure storage layouts are compatible first:
// forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract QuestFactory
// forge script script/QuestFactory.s.sol:QuestFactoryUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract QuestFactoryUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address questfactoryAddress = 0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E;
        address proxyAdminAddress = 0xD28fbF7569f31877922cDc31a1A5B3C504E8faa1;
        ITransparentUpgradeableProxy questfactoryProxy = ITransparentUpgradeableProxy(payable(questfactoryAddress));

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin(proxyAdminAddress).upgrade(questfactoryProxy, address(new QuestFactory()));

        vm.stopBroadcast();
    }
}