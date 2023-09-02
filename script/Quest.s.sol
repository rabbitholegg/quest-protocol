// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {QuestFactory} from "../contracts/QuestFactory.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";

// # To deploy and verify Quest.sol run this command below
// forge script script/Quest.s.sol:QuestDeploy --rpc-url sepolia --broadcast --verify -vvvv
contract QuestDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        QuestFactory(C.QUEST_FACTORY_ADDRESS).setErc20QuestAddress(address(new Quest()));

        vm.stopBroadcast();
    }
}

// # To deploy and verify Quest1155.sol run this command below
// forge script script/Quest.s.sol:Quest1155Deploy --rpc-url sepolia --broadcast --verify -vvvv
contract Quest1155Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        QuestFactory(C.QUEST_FACTORY_ADDRESS).setErc1155QuestAddress(address(new Quest1155()));

        vm.stopBroadcast();
    }
}