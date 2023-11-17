// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
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
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    uint40 DURATION_TOTAL = 0;
    address sablierMock;
    address questFactoryMock;
    Quest quest;
    address admin = makeAddr(("admin"));
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
        quest = new Quest();
        quest =
            Quest(address(quest).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "test_fuzz_singleClaim"))));
        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            endTime,
            startTime,
            TOTAL_PARTICIPANTS,
            rewardAmountInWei,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            DURATION_TOTAL,
            sablierMock
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
        uint256 totalFees = calculateTotalFees(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE) / 2;
        uint256 questBalance = SampleERC20(rewardTokenAddress).balanceOf(address(quest));
        uint256 questBalanceMinusFees = questBalance - totalFees;
        // Simulate the quest being completed by max participants
        QuestFactoryMock(questFactoryMock).setNumberMinted(TOTAL_PARTICIPANTS);
        vm.warp(END_TIME);
        vm.prank(protocolFeeRecipient);
        quest.withdrawRemainingTokens();
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(protocolFeeRecipient),
            totalFees,
            "protocolFeeRecipient should have received the remaining tokens"
        );
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(address(questFactoryMock)),
            questBalanceMinusFees,
            "quest should have 0 tokens"
        );
    }

    function test_fuzz_withdrawRemainingTokens(
        uint16 withdrawerRoll,
        uint256 totalClaims,
        uint256 rewardAmountInWei,
        uint16 questFee
    ) public {
        address[2] memory withdrawers = [protocolFeeRecipient, questFactoryMock];
        address withdrawer = withdrawers[withdrawerRoll % 2];
        totalClaims = bound(totalClaims, 1, TOTAL_PARTICIPANTS);
        questFee = uint16(bound(questFee, 0, 10_000));
        rewardAmountInWei =
            bound(rewardAmountInWei, REWARD_AMOUNT_IN_WEI * totalClaims, REWARD_AMOUNT_IN_WEI * REWARD_AMOUNT_IN_WEI);
        // Setup a reward token with fuzzed rewardAmountInWei
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(totalClaims, rewardAmountInWei, questFee);
        rewardTokenAddress = address(
            new SampleERC20(
                DEFAULT_ERC20_NAME,
                DEFAULT_ERC20_SYMBOL,
                defaultTotalRewardsPlusFee,
                admin
            )
        );
        // Get the participants starting balance
        // uint256 startingBalance = SampleERC20(rewardTokenAddress).balanceOf(participant);
        // Create new quest with fuzzed values
        quest = new Quest();
        quest =
            Quest(address(quest).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "test_fuzz_singleClaim"))));
        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            END_TIME,
            START_TIME,
            totalClaims,
            rewardAmountInWei,
            QUEST_ID,
            questFee,
            protocolFeeRecipient,
            DURATION_TOTAL,
            sablierMock
        );
        // Transfer all tokens to quest
        vm.prank(admin);
        SampleERC20(rewardTokenAddress).transfer(address(quest), defaultTotalRewardsPlusFee);
        // Simulate claims
        for (uint256 i = 0; i < totalClaims; i++) {
            address claimer = makeAddr(string.concat("Claimer", i.toString()));
            vm.warp(START_TIME + i);
            vm.prank(questFactoryMock);
            quest.singleClaim(claimer);
        }
        QuestFactoryMock(questFactoryMock).setNumberMinted(totalClaims);
        // Get final balances and withdraw remaining tokens
        vm.warp(END_TIME);
        uint256 totalFees = calculateTotalFees(totalClaims, rewardAmountInWei, questFee) / 2;
        uint256 questBalance = SampleERC20(rewardTokenAddress).balanceOf(address(quest));
        uint256 questBalanceMinusFees = questBalance - totalFees;
        vm.prank(withdrawer);
        quest.withdrawRemainingTokens();
        // Check owner and fee recipient received the correct amount of tokens
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(protocolFeeRecipient),
            totalFees,
            "protocolFeeRecipient should have received the remaining tokens"
        );
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(address(questFactoryMock)),
            questBalanceMinusFees,
            "quest should have 0 tokens"
        );
    }

    function test_RevertIf_withdrawRemainingToken_NoWithdrawDuringClaim() public {
        vm.expectRevert(abi.encodeWithSelector(NoWithdrawDuringClaim.selector));
        vm.prank(protocolFeeRecipient);
        quest.withdrawRemainingTokens();
    }

    function test_RevertIf_withdrawRemainingToken_AlreadyWithdrawn() public {
        vm.warp(END_TIME);
        vm.startPrank(protocolFeeRecipient);
        quest.withdrawRemainingTokens();
        vm.expectRevert(abi.encodeWithSelector(AlreadyWithdrawn.selector));
        quest.withdrawRemainingTokens();
        vm.stopPrank();
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

    function test_fuzz_protocolFee(uint256 totalClaims) public {
        totalClaims = bound(totalClaims, 1, TOTAL_PARTICIPANTS);
        QuestFactoryMock(questFactoryMock).setNumberMinted(totalClaims);

        assertEq(quest.protocolFee(), calculateTotalFees(totalClaims, REWARD_AMOUNT_IN_WEI, QUEST_FEE));
    }

    function test_fuzz_receiptRedeemers(uint256 redeemers) public {
        assertEq(quest.receiptRedeemers(), 0, "receiptRedeemers should be correct");
        QuestFactoryMock(questFactoryMock).setNumberMinted(redeemers);
        assertEq(quest.receiptRedeemers(), redeemers, "receiptRedeemers should be correct");
    }

    function test_getRewardAmount() public {
        assertEq(quest.getRewardAmount(), REWARD_AMOUNT_IN_WEI, "getRewardAmount should be correct");
    }

    function test_getRewardToken() public {
        assertEq(quest.getRewardToken(), rewardTokenAddress, "getRewardToken should be correct");
    }
}
