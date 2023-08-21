// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./helpers/TestUtils.sol";
import "/contracts/test/SampleERC20.sol";
import "./mocks/QuestFactoryMock.sol";
import "./mocks/SablierMock.sol";
import "/contracts/Quest.sol";

contract TestQuest is Test, TestUtils {
    address rewardTokenAddress;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 TOTAL_REWARDS_IN_WEI = 1000;
    string QUEST_ID = "QUEST_ID";
    uint16 QUEST_FEE = 2000; // 20%
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    uint40 DURATION_TOTAL = 1_000_000;
    address sablierMock;
    address questFactoryMock;
    Quest quest;

    function setup() public {
        rewardTokenAddress = address(new SampleERC20());
        sablierMock = address(new SablierMock());
        questFactoryMock = address(new QuestFactoryMock());
        vm.prank(questFactoryMock);
        quest = new Quest(
            rewardTokenAddress,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            TOTAL_REWARDS_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            DURATION_TOTAL,
            sablierMock,
            questFactoryMock
        );
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function test_initialize() public {
        assertEq(rewardTokenAddress, quest.rewardToken(), "rewardTokenAddress not set");
        assertEq(END_TIME, quest.endTime(), "endTime not set");
        assertEq(START_TIME, quest.startTime(), "startTime not set");
        assertEq(TOTAL_PARTICIPANTS, quest.totalParticipants(), "totalParticipants not set");
        assertEq(TOTAL_REWARDS_IN_WEI, quest.totalRewardsInWei(), "totalRewardsInWei not set");
        assertEq(QUEST_ID, quest.questId(), "questId not set");
        assertEq(QUEST_FEE, quest.questFee(), "questFee not set");
        assertEq(protocolFeeRecipient, quest.protocolFeeRecipient(), "protocolFeeRecipient not set");
        assertEq(DURATION_TOTAL, quest.durationTotal(), "durationTotal not set");
        assertEq(sablierMock, quest.sablierV2LockupLinearContract(), "sablier not set");
        assertEq(questFactoryMock, quest.questFactoryContract(), "questFactory not set");
        assertTrue(quest.isInitialized(), "isInitialized should be true");
        assertTrue(quest.queued(), "queued should be true");
        assertFalse(quest.hasWithdrawn(), "hasWithdrawn should be false");
    }

    function test_RevertIf_initialize_EndTimeInPast() public {}

    function test_RevertIf_initialize_EndTimeLessThanOrEqualToStartTime() public {}

    /*//////////////////////////////////////////////////////////////
                                PAUSE
    //////////////////////////////////////////////////////////////*/
    function test_pause() public {}

    function test_RevertIf_pause_Unauthorized() public {}

    /*//////////////////////////////////////////////////////////////
                              UNPAUSE
    //////////////////////////////////////////////////////////////*/
    function test_unpause() public {}

    function test_RevertIf_unpause_Unauthorized() public {}

    /*//////////////////////////////////////////////////////////////
                            SINGLECLAIM
    //////////////////////////////////////////////////////////////*/
    function test_singleClaim() public {}

    function test_fuzz_singleClaim() public {}

    function test_RevertIf_singleClaim_NotQuestFactory() public {}

    function test_RevertIf_singleClaim_ClaimWindowNotStarted() public {}

    function test_RevertIf_singleClaim_whenNotPaused() public {}

    /*//////////////////////////////////////////////////////////////
                      WITHDRAWREMAININGTOKENS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawRemainingTokens() public {}

    function test_fuzz_withdrawRemainingTokens() public {}

    function test_RevertIf_withdrawRemainingToken_NoWithdrawDuringClaim() public {}

    function test_RevertIf_withdrawRemainingToken_AuthOwnerRecipient() public {}

    function test_RevertIf_withdrawRemainingToken_AlreadyWithdrawn() public {}

    /*//////////////////////////////////////////////////////////////
                                REFUND
    //////////////////////////////////////////////////////////////*/

    function test_refund() public {}

    function test_fuzz_refund() public {}

    function test_RevertIf_refund_Unauthorized() public {}

    function test_RevertIf_refund_InvalidRefundToken() public {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    function test_totalTransferAmount() public {}

    function test_maxTotalRewards() public {}

    function test_maxProtocolReward() public {}

    function test_protocolFee() public {}

    function test_receiptRedeemers() public {}

    function test_getRewardAmount() public {}

    function test_getRewardToken() public {}
}
