// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
import {Quest} from "contracts/Quest.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {Errors} from "./helpers/errors.sol";

contract TestQuest is Test, TestUtils, Errors {
    using LibClone for address;

    address rewardTokenAddress;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 REWARD_AMOUNT_IN_WEI = 1000;
    string QUEST_ID = "QUEST_ID";
    uint16 QUEST_FEE = 2000; // 20%
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    uint40 DURATION_TOTAL = 1_000_000;
    address sablierMock;
    address questFactoryMock;
    Quest quest;
    address admin = makeAddr(("admin"));
    uint256 defaultTotalRewardsPlusFee;
    string constant DEFAULT_ERC20_NAME = "RewardToken";
    string constant DEFAULT_ERC20_SYMBOL = "RTC";

    function setUp() public {
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE);
        rewardTokenAddress = address(
            new SampleERC20(      
                DEFAULT_ERC20_NAME,
                DEFAULT_ERC20_SYMBOL,
                defaultTotalRewardsPlusFee,
                admin
            )
        );
        sablierMock = address(new SablierMock());
        questFactoryMock = address(new QuestFactoryMock());
        quest = new Quest();
        quest = Quest(address(quest).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            DURATION_TOTAL,
            sablierMock
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
        assertEq(REWARD_AMOUNT_IN_WEI, quest.rewardAmountInWei(), "totalRewardsInWei not set");
        assertEq(QUEST_ID, quest.questId(), "questId not set");
        assertEq(QUEST_FEE, quest.questFee(), "questFee not set");
        assertEq(protocolFeeRecipient, quest.protocolFeeRecipient(), "protocolFeeRecipient not set");
        assertEq(DURATION_TOTAL, quest.durationTotal(), "durationTotal not set");
        assertEq(sablierMock, address(quest.sablierV2LockupLinearContract()), "sablier not set");
        assertEq(questFactoryMock, address(quest.questFactoryContract()), "questFactory not set");
        assertTrue(quest.queued(), "queued should be true");
        assertFalse(quest.hasWithdrawn(), "hasWithdrawn should be false");
    }

    function test_RevertIf_initialize_EndTimeInPast() public {
        vm.warp(END_TIME + 1);
        quest = new Quest();
        quest = Quest(address(quest).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        vm.prank(questFactoryMock);
        vm.expectRevert(abi.encodeWithSelector(EndTimeInPast.selector));
        quest.initialize(
            rewardTokenAddress,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            DURATION_TOTAL,
            sablierMock
        );
    }

    function test_RevertIf_initialize_EndTimeLessThanOrEqualToStartTime() public {
        quest = new Quest();
        quest = Quest(address(quest).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        vm.prank(questFactoryMock);
        vm.expectRevert(abi.encodeWithSelector(EndTimeLessThanOrEqualToStartTime.selector));
        quest.initialize(
            rewardTokenAddress,
            START_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            DURATION_TOTAL,
            sablierMock
        );
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSE
    //////////////////////////////////////////////////////////////*/
    function test_pause() public {
        vm.prank(questFactoryMock);
        quest.pause();
        assertTrue(quest.paused(), "paused should be true");
    }

    function test_RevertIf_pause_Unauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        quest.pause();
    }

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
