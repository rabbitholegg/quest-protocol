// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {QuestBudget} from "../contracts/QuestBudget.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";

contract QuestBudgetDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address operator = vm.envUint("MAINNET_QUEST_BUDGET_OPERATOR");
        address owner = vm.envUint("MAINNET_QUEST_BUDGET_OWNER");
        address[] memory authorized = new address[](1);
        authorized[0] = operator; // Add more authorized addresses if needed

        vm.startBroadcast(deployerPrivateKey);

        // Deploy QuestBudget
        QuestBudget questBudget = new QuestBudget();
        bytes memory initData = abi.encode(owner, C.QUEST_FACTORY_ADDRESS, authorized);
        questBudget.initialize(initData);

        vm.stopBroadcast();
    }
}