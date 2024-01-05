// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Soulbound20} from "contracts/Soulbound20.sol";
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
    address user = makeAddr("user");
    address admin = makeAddr(("admin"));
    address owner = makeAddr(("owner"));
    address participant = makeAddr(("participant"));
    uint256 defaultTotalRewardsPlusFee;
    string constant DEFAULT_ERC20_NAME = "RewardToken";
    string constant DEFAULT_ERC20_SYMBOL = "RTC";
    string constant QUEST_TYPE = "erc20";

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
            protocolFeeRecipient,
            QUEST_TYPE
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
        assertEq(QUEST_TYPE, quest.questType(), "questType not set");
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
            protocolFeeRecipient,
            QUEST_TYPE
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
            protocolFeeRecipient,
            QUEST_TYPE
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
                            claimFromFactory
    //////////////////////////////////////////////////////////////*/
    function test_claimFromFactory() public {
        uint256 startingBalance = SampleERC20(rewardTokenAddress).balanceOf(participant);
        vm.warp(START_TIME);
        vm.prank(questFactoryMock);
        quest.claimFromFactory(participant, address(0));
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(participant),
            startingBalance + REWARD_AMOUNT_IN_WEI,
            "participant should have received the reward"
        );
    }

    function test_fuzz_claimFromFactory(
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
        address payable questAddress = payable(address(new Quest()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "test_fuzz_claimFromFactory"))));
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
            protocolFeeRecipient,
            QUEST_TYPE
        );
        // Transfer all tokens to quest
        vm.prank(admin);
        SampleERC20(rewardTokenAddress).transfer(address(quest), defaultTotalRewardsPlusFee);
        // Claim single and check for correct event logging
        vm.warp(startTime);
        vm.prank(questFactoryMock);
        quest.claimFromFactory(participant, address(0));
        // Check that the participant received the correct amount of tokens
        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(participant),
            startingBalance + rewardAmountInWei,
            "participant should have received the reward"
        );
    }

    function test_claimFromFactory_erc20points() public {
        address ref = makeAddr("ref");
        address payable erc20PointsContract = payable(address(new Soulbound20()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        Soulbound20(erc20PointsContract).initialize(owner, "ERC20Points", "ERC20Points");
        uint256 mintRole = Soulbound20(erc20PointsContract).MINT_ROLE();

        questFactoryMock = address(new QuestFactoryMock());
        address payable questAddress = payable(address(new Quest()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest(questAddress);
        vm.prank(owner);
        quest.initialize(
            erc20PointsContract,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            "erc20Points"
        );

        vm.prank(owner);
        Soulbound20(erc20PointsContract).grantRoles(questAddress, mintRole);
        vm.warp(START_TIME);
        vm.prank(owner);
        quest.claimFromFactory(participant, ref);

        // REWARD_AMOUNT_IN_WEI to claimer
        assertEq(Soulbound20(erc20PointsContract).balanceOf(participant), REWARD_AMOUNT_IN_WEI);

        // REWARD_AMOUNT_IN_WEI * 10% to creator
        assertEq(Soulbound20(erc20PointsContract).balanceOf(owner), REWARD_AMOUNT_IN_WEI * 10 / 100);

        // REWARD_AMOUNT_IN_WEI * 5% to community treasury
        assertEq(Soulbound20(erc20PointsContract).balanceOf(protocolFeeRecipient), REWARD_AMOUNT_IN_WEI * 5 / 100);

        // REWARD_AMOUNT_IN_WEI * 5% to referrer
        assertEq(Soulbound20(erc20PointsContract).balanceOf(ref), REWARD_AMOUNT_IN_WEI * 5 / 100);
    }

    function test_RevertIf_claimFromFactory_NotQuestFactory() public {
        vm.warp(START_TIME);
        vm.expectRevert(abi.encodeWithSelector(NotQuestFactory.selector));
        quest.claimFromFactory(participant, address(0));
    }

    function test_RevertIf_claimFromFactory_QuestEnded() public {
        vm.warp(END_TIME + 1);
        vm.prank(questFactoryMock);
        vm.expectRevert(abi.encodeWithSelector(QuestEnded.selector));
        quest.claimFromFactory(participant, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                      WITHDRAWREMAININGTOKENS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawRemainingTokensQ() public {
        uint256 startingBalance = SampleERC20(rewardTokenAddress).balanceOf(owner);
        uint256 defaultTotalRewardsPlusFees = calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE);

        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);
        vm.warp(END_TIME);
        quest.withdrawRemainingTokens();

        // no tokens withdrawn
        assertEq(SampleERC20(rewardTokenAddress).balanceOf(owner), defaultTotalRewardsPlusFees + startingBalance);
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
