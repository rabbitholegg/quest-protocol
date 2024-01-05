// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";

contract TestQuest is Test, TestUtils, Errors, Events {
    using LibClone for address;
    using LibString for uint256;

    address rewardTokenAddress;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 REWARD_AMOUNT_IN_WEI = 1000;
    string QUEST_ID = "QUEST_ID";
    uint16 QUEST_FEE = 2000; // 20%
    uint256 CLAIM_FEE = 999;
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address questFactoryMock;
    Quest quest;
    address admin = makeAddr(("admin"));
    address owner = makeAddr(("owner"));
    address participant = makeAddr(("participant"));
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
        questFactoryMock = address(new QuestFactoryMock());
        address payable questAddress = payable(address(new Quest()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest(questAddress);
        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient
        );
        // Transfer all tokens to quest
        vm.prank(admin);
        SampleERC20(rewardTokenAddress).transfer(address(quest), defaultTotalRewardsPlusFee);
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
        assertEq(questFactoryMock, address(quest.questFactoryContract()), "questFactory not set");
        assertTrue(quest.queued(), "queued should be true");
        assertFalse(quest.hasWithdrawn(), "hasWithdrawn should be false");
    }

    function test_RevertIf_initialize_EndTimeInPast() public {
        vm.warp(END_TIME + 1);
        address payable questAddress = payable(address(new Quest()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest(questAddress);
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
            protocolFeeRecipient
        );
    }

    function test_RevertIf_initialize_EndTimeLessThanOrEqualToStartTime() public {
        address payable questAddress = payable(address(new Quest()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest(questAddress);
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
            protocolFeeRecipient
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
    function test_unpause() public {
        vm.startPrank(questFactoryMock);
        quest.pause();
        quest.unPause();
        assertFalse(quest.paused(), "paused should be false");
        vm.stopPrank();
    }

    function test_RevertIf_unpause_Unauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        quest.unPause();
    }

    /*//////////////////////////////////////////////////////////////
                            SINGLECLAIM
    //////////////////////////////////////////////////////////////*/
    function test_singleClaim() public {
        uint256 startingBalance = SampleERC20(rewardTokenAddress).balanceOf(participant);
        vm.warp(START_TIME);
        vm.prank(questFactoryMock);
        quest.singleClaim(participant);
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(participant),
            startingBalance + REWARD_AMOUNT_IN_WEI,
            "participant should have received the reward"
        );
    }

    function test_fuzz_singleClaim(
        uint256 rewardAmountInWei,
        uint256 startTime,
        uint256 endTime,
        uint256 currentTime
    ) public {
        vm.warp(0);
        // Make sure our params have reasonable bounds
        startTime = bound(startTime, block.timestamp, END_TIME - 1);
        endTime = bound(endTime, startTime + 1, END_TIME);
        currentTime = bound(currentTime, startTime, endTime - 1);
        rewardAmountInWei = bound(rewardAmountInWei, 1, REWARD_AMOUNT_IN_WEI * REWARD_AMOUNT_IN_WEI);
        // Setup a reward token with fuzzed rewardAmountInWei
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, rewardAmountInWei, QUEST_FEE);
        rewardTokenAddress = address(
            new SampleERC20(
                DEFAULT_ERC20_NAME,
                DEFAULT_ERC20_SYMBOL,
                defaultTotalRewardsPlusFee,
                admin
            )
        );
        // Get the participants starting balance
        uint256 startingBalance = SampleERC20(rewardTokenAddress).balanceOf(participant);
        // Create new quest with fuzzed values
        address payable questAddress = payable(address(new Quest()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "test_fuzz_singleClaim"))));
        quest = Quest(questAddress);

        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            endTime,
            startTime,
            TOTAL_PARTICIPANTS,
            rewardAmountInWei,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient
        );
        // Transfer all tokens to quest
        vm.prank(admin);
        SampleERC20(rewardTokenAddress).transfer(address(quest), defaultTotalRewardsPlusFee);
        // Claim single and check for correct event logging
        vm.warp(startTime);
        vm.prank(questFactoryMock);
        quest.singleClaim(participant);
        // Check that the participant received the correct amount of tokens
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(participant),
            startingBalance + rewardAmountInWei,
            "participant should have received the reward"
        );
    }

    function test_singleClaim_stream() public {}

    function test_RevertIf_singleClaim_NotQuestFactory() public {
        vm.warp(START_TIME);
        vm.expectRevert(abi.encodeWithSelector(NotQuestFactory.selector));
        quest.singleClaim(participant);
    }

    function test_RevertIf_singleClaim_ClaimWindowNotStarted() public {
        vm.warp(START_TIME - 1);
        vm.prank(questFactoryMock);
        vm.expectRevert(abi.encodeWithSelector(ClaimWindowNotStarted.selector));
        quest.singleClaim(participant);
    }

    function test_RevertIf_singleClaim_whenNotPaused() public {
        vm.startPrank(questFactoryMock);
        quest.pause();
        vm.warp(START_TIME);
        vm.expectRevert("Pausable: paused");
        quest.singleClaim(participant);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      WITHDRAWREMAININGTOKENS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawRemainingTokens() public {
        QuestFactoryMock(questFactoryMock).setMintFee(CLAIM_FEE);
        QuestFactoryMock(questFactoryMock).setNumberMinted(TOTAL_PARTICIPANTS);

        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);

        // simulate ETH from TOTAL_PARTICIPANTS claims
        vm.deal(address(quest), (CLAIM_FEE * TOTAL_PARTICIPANTS * 2) / 3);

        uint256 totalFees = calculateTotalFees(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE) / 2;
        uint256 questBalance = SampleERC20(rewardTokenAddress).balanceOf(address(quest));
        uint256 questBalanceMinusFees = questBalance - totalFees;

        vm.warp(END_TIME);
        quest.withdrawRemainingTokens();

        assertEq(
            owner.balance,
            CLAIM_FEE * TOTAL_PARTICIPANTS * 1 / 3,
            "owner should have received (claimFee * redeemedTokens) / 3 eth"
        );
        assertEq(
            protocolFeeRecipient.balance,
            CLAIM_FEE * TOTAL_PARTICIPANTS * 1 / 3,
            "owner should have received remaining ETH"
        );

        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(protocolFeeRecipient),
            totalFees,
            "protocolFeeRecipient should have received the remaining tokens"
        );
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(owner),
            questBalanceMinusFees,
            "quest owner should have 0 tokens"
        );
    }

    function test_RevertIf_withdrawRemainingToken_NoWithdrawDuringClaim() public {
        vm.expectRevert(abi.encodeWithSelector(NoWithdrawDuringClaim.selector));
        vm.prank(protocolFeeRecipient);
        quest.withdrawRemainingTokens();
    }

    function test_RevertIf_withdrawRemainingToken_AlreadyWithdrawn() public {
        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);

        // simulate ETH from 1 claim
        vm.deal(address(quest), CLAIM_FEE / 3 * 2);

        vm.warp(END_TIME);
        quest.withdrawRemainingTokens();

        vm.expectRevert(abi.encodeWithSelector(AlreadyWithdrawn.selector));
        quest.withdrawRemainingTokens();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    function test_totalTransferAmount() public {
        assertEq(quest.totalTransferAmount(), defaultTotalRewardsPlusFee, "totalTransferAmount should be correct");
    }

    function test_maxTotalRewards() public {
        assertEq(
            quest.maxTotalRewards(),
            calculateTotalRewards(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI),
            "maxTotalRewards should be correct"
        );
    }

    function test_maxProtocolReward() public {
        assertEq(
            quest.maxProtocolReward(),
            calculateTotalFees(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE),
            "maxProtocolReward should be correct"
        );
    }

    function test_getRewardAmount() public {
        assertEq(quest.getRewardAmount(), REWARD_AMOUNT_IN_WEI, "getRewardAmount should be correct");
    }

    function test_getRewardToken() public {
        assertEq(quest.getRewardToken(), rewardTokenAddress, "getRewardToken should be correct");
    }
}
