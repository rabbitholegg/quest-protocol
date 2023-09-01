// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {QuestFactory} from "../contracts/QuestFactory.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// # To Upgrade QuestFactory.sol run this command below
// ! important: make sure storage layouts are compatible first:
// yarn clean && forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract QuestFactory
// forge script script/QuestFactory.s.sol:QuestFactoryUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract QuestFactoryUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address questfactoryAddress = 0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E;
        address proxyAdminAddress = 0xD28fbF7569f31877922cDc31a1A5B3C504E8faa1;
        ITransparentUpgradeableProxy questfactoryProxy = ITransparentUpgradeableProxy(payable(questfactoryAddress));

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin(proxyAdminAddress).upgrade(questfactoryProxy, address(new QuestFactory()));
        QuestFactory(payable(questfactoryAddress)).setDefaultReferralFeeRecipient(0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c);

        vm.stopBroadcast();
    }
}

// default referral fee recipient
// arb 0x1E72B525dFD16dCE7680d4A8c3625Ff100297143
// base 0x21f06A18c0b7ca98Aa305773A75cF70FF9A6060d
// mainnet 0x46e9b312510F5D2D28124a09983646E161280c0b
// polygon 0xFc0dB6d5E37198Ed146d981643535b6216534855
// opt 0x4ed491BBe48acEf42ab81E2Ffa9a25Ba496942f1
// sepolia 0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c