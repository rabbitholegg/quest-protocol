// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {QuestBudget} from "../contracts/QuestBudget.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {LibClone} from "solady/utils/LibClone.sol";

contract QuestBudgetDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("QUEST_BUDGET_DEPLOYER_PRIVATE_KEY");
        address operator = vm.envAddress("QUEST_BUDGET_OPERATOR");
        address owner = vm.envAddress("QUEST_BUDGET_OWNER");
        address[] memory authorized = new address[](1);
        authorized[0] = operator; // Add more authorized addresses if needed

        vm.startBroadcast(deployerPrivateKey);

        // Deploy QuestBudget
        QuestBudget questBudget = QuestBudget(payable(LibClone.clone(address(new QuestBudget()))));
        questBudget.initialize(
            abi.encode(QuestBudget.InitPayload({owner: owner, questFactory: C.QUEST_FACTORY_ADDRESS, authorized: authorized}))
        );
        vm.stopBroadcast();
    }
}