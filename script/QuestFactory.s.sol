// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {QuestFactory} from "../contracts/QuestFactory.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

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

        vm.stopBroadcast();
    }
}

contract QuestFactoryDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address owner = vm.envAddress("MAINNET_PRIVATE_KEY_PUBLIC_ADDRESS");
        address claimSigner = vm.envAddress("CLAIM_SIGNER_ADDRESS");
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
        QuestFactory(C.QUEST_FACTORY_ADDRESS).initialize(
            claimSigner,                        // claimSignerAddress_
            owner,                              // protocolFeeRecipient_
            address(new Quest()),               // erc20QuestAddress_
            payable(address(new Quest1155())),  // erc1155QuestAddress_
            owner,                              // ownerAddress_
            owner,                              // defaultReferralFeeRecipientAddress_
            address(0),                         // sablierV2LockupLinearAddress_
            500000000000000,                    // nftQuestFee_,
            5000,                               // referralFee_,
            75000000000000                      // mintFee_
        );

        vm.stopBroadcast();
    }
}