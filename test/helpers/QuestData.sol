// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract QuestData is Test {

    struct MockQuestData {
        uint256 END_TIME;
        uint256 START_TIME ;
        uint256 TOTAL_PARTICIPANTS ;
        string QUEST_ID_STRING;
        bytes16 QUEST_ID;
        string  ACTION_TYPE;
        string QUEST_NAME;
        string PROJECT_NAME;
        uint32 CHAIN_ID;
        bytes32 TX_HASH;
        string  JSON_MSG;
        uint256 REWARD_AMOUNT;
        uint256 REFERRAL_REWARD_FEE;
    }
  
}
