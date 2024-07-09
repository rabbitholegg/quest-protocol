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
    uint256 REWARD_AMOUNT_IN_WEI = 10_000_000_000;
    string QUEST_ID = "QUEST_ID";
    uint16 QUEST_FEE = 250; // 2.5%
    uint256 CLAIM_FEE = 999;
    uint16 REFERRAL_REWARD_FEE = 250; // 2.5%
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address questFactoryMock;
    Quest quest;
    address admin = makeAddr(("admin"));
    address owner = makeAddr(("owner"));
    address participant = makeAddr(("participant"));
    address referrer = makeAddr(("referrer"));
    uint256 defaultTotalRewardsPlusFee;
    string constant DEFAULT_ERC20_NAME = "RewardToken";
    string constant DEFAULT_ERC20_SYMBOL = "RTC";

    function setUp() public {
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE, REFERRAL_REWARD_FEE);
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
            REFERRAL_REWARD_FEE
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
            protocolFeeRecipient,
            REFERRAL_REWARD_FEE
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
            REFERRAL_REWARD_FEE
        );
    }

    /*//////////////////////////////////////////////////////////////
                                CANCEL
    //////////////////////////////////////////////////////////////*/
    function test_cancel() public {
        vm.prank(questFactoryMock);
        quest.cancel();
        assertTrue(quest.paused(), "paused should be true");
        assertEq(quest.endTime(), block.timestamp, "endTime should be now (quest not started)");
    }

    function test_cancel_afterStarted() public {
        vm.warp(START_TIME);
        vm.prank(questFactoryMock);
        quest.cancel();
        assertTrue(quest.paused(), "paused should be true");
        assertEq(quest.endTime(), block.timestamp + 15 minutes, "endTime should be 15 minutes from now");
    }

    function test_cancel_alreadyCanceled() public {
        vm.prank(questFactoryMock);
        quest.cancel();
        vm.expectRevert("Pausable: paused");
        vm.prank(questFactoryMock);
        quest.cancel();
    }

    function test_RevertIf_cancel_Unauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(NotQuestFactory.selector));
        quest.cancel();
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
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, rewardAmountInWei, QUEST_FEE, REFERRAL_REWARD_FEE);
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
            protocolFeeRecipient,
            REFERRAL_REWARD_FEE
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

        uint256 totalFees = calculateTotalProtocolFees(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE);
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
                        CLAIM REFERRAL FEES
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_claimReferralFees(uint96 timestamp, uint256 participants) public {
        timestamp = uint96(bound(timestamp, START_TIME+10, END_TIME));
        participants = bound(participants, 1, TOTAL_PARTICIPANTS);

        vm.startPrank(admin);
        // Transfer the appropriate amount of Reward tokens to the quest based on fuzzed participants
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(participants, REWARD_AMOUNT_IN_WEI, QUEST_FEE, REFERRAL_REWARD_FEE);
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
        vm.stopPrank();
        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            timestamp,
            START_TIME,
            participants,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            REFERRAL_REWARD_FEE
        );

        vm.startPrank(admin);
        // Set all mocked values in the quest factory
        QuestFactoryMock(questFactoryMock).setMintFee(CLAIM_FEE);
        QuestFactoryMock(questFactoryMock).setNumberMinted(participants);
        // Transfer all tokens to quest
        SampleERC20(rewardTokenAddress).transfer(address(quest), defaultTotalRewardsPlusFee);
        vm.stopPrank();

        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);

        // simulate ETH from TOTAL_PARTICIPANTS claims
        vm.deal(address(quest), (CLAIM_FEE * participants * 2) / 3);

        vm.warp(START_TIME);
        for(uint256 i = 1; i <= participants; i++) {
            participant = makeAddr(i.toString());
            vm.prank(questFactoryMock);

            quest.claimFromFactory(participant, referrer);
            assertEq(
                SampleERC20(rewardTokenAddress).balanceOf(participant),
                quest.getRewardAmount(),
                "participant should get the reward amount"
            );
            assertEq(
                quest.getReferralAmount(referrer),
                quest.referralRewardAmount() * i,
                "referrer should increase referral rewards after claim"
            );
            assertEq(
                quest.referralClaimTotal(),
                quest.referralRewardAmount() * i,
                "referral claims for all referrers should equal the reward amount (single claim)"
            );
        }

        vm.warp(timestamp);
        vm.prank(referrer);

        // verify that withdrawals can still work
        quest.withdrawRemainingTokens();

        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(address(quest)),
            quest.referralClaimTotal(),
            "expected to have referralClaimTotal() amount left inside the contract"
        );

        quest.claimReferralFees(referrer);

        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(referrer),
            quest.referralRewardAmount() * participants,
            "referrer should claim their allocated referral rewards"
        );

        uint256 participantBalance = SampleERC20(rewardTokenAddress).balanceOf(participant);
        uint256 protocolFeeRecipientBalance = SampleERC20(rewardTokenAddress).balanceOf(quest.protocolFeeRecipient());
        uint256 ownerBalance = SampleERC20(rewardTokenAddress).balanceOf(owner);
        uint256 referrerBalance = SampleERC20(rewardTokenAddress).balanceOf(referrer);
        uint256 total = participantBalance + ownerBalance + referrerBalance + protocolFeeRecipientBalance;

        assertEq(
            protocolFeeRecipientBalance,
            quest.protocolFee(),
            "Protocol fee recipient should get their share of the rewards"
        );

        assertEq(
            ownerBalance,
            total - participantBalance - referrerBalance - protocolFeeRecipientBalance,
            "Owner balance should have the unclaimed funds returned"
        );
    }

    function test_fuzz_claimReferralFees_withdrawAfterClaim(uint96 timestamp, uint256 participants) public {
        timestamp = uint96(bound(timestamp, START_TIME+10, END_TIME));
        participants = bound(participants, 1, TOTAL_PARTICIPANTS);

        vm.startPrank(admin);
        // Transfer the appropriate amount of Reward tokens to the quest based on fuzzed participants
        defaultTotalRewardsPlusFee = calculateTotalRewardsPlusFee(participants, REWARD_AMOUNT_IN_WEI, QUEST_FEE, REFERRAL_REWARD_FEE);
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
        vm.stopPrank();
        vm.prank(questFactoryMock);
        quest.initialize(
            rewardTokenAddress,
            timestamp,
            START_TIME,
            participants,
            REWARD_AMOUNT_IN_WEI,
            QUEST_ID,
            QUEST_FEE,
            protocolFeeRecipient,
            REFERRAL_REWARD_FEE
        );

        vm.startPrank(admin);
        // Set all mocked values in the quest factory
        QuestFactoryMock(questFactoryMock).setMintFee(CLAIM_FEE);
        QuestFactoryMock(questFactoryMock).setNumberMinted(participants);
        // Transfer all tokens to quest
        SampleERC20(rewardTokenAddress).transfer(address(quest), defaultTotalRewardsPlusFee);
        vm.stopPrank();

        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);

        // simulate ETH from TOTAL_PARTICIPANTS claims
        vm.deal(address(quest), (CLAIM_FEE * participants * 2) / 3);

        vm.warp(START_TIME);
        for(uint256 i = 1; i <= participants; i++) {
            participant = makeAddr(i.toString());
            vm.prank(questFactoryMock);

            quest.claimFromFactory(participant, referrer);
            assertEq(
                SampleERC20(rewardTokenAddress).balanceOf(participant),
                quest.getRewardAmount(),
                "participant should get the reward amount"
            );
            assertEq(
                quest.getReferralAmount(referrer),
                quest.referralRewardAmount() * i,
                "referrer should increase referral rewards after claim"
            );
            assertEq(
                quest.referralClaimTotal(),
                quest.referralRewardAmount() * i,
                "referral claims for all referrers should equal the reward amount (single claim)"
            );
        }

        vm.warp(timestamp);
        vm.prank(referrer);

        quest.claimReferralFees(referrer);

        // verify that withdrawals can still work
        quest.withdrawRemainingTokens();

        assertEq(
            SampleERC20(rewardTokenAddress).balanceOf(referrer),
            quest.referralRewardAmount() * participants,
            "referrer should claim their allocated referral rewards"
        );

        uint256 participantBalance = SampleERC20(rewardTokenAddress).balanceOf(participant);
        uint256 protocolFeeRecipientBalance = SampleERC20(rewardTokenAddress).balanceOf(quest.protocolFeeRecipient());
        uint256 ownerBalance = SampleERC20(rewardTokenAddress).balanceOf(owner);
        uint256 referrerBalance = SampleERC20(rewardTokenAddress).balanceOf(referrer);
        uint256 total = participantBalance + ownerBalance + referrerBalance + protocolFeeRecipientBalance;

        assertEq(
            protocolFeeRecipientBalance,
            quest.protocolFee(),
            "Protocol fee recipient should get their share of the rewards"
        );

        assertEq(
            ownerBalance,
            total - participantBalance - referrerBalance - protocolFeeRecipientBalance,
            "Owner balance should have the unclaimed funds returned"
        );
    }

    function test_RevertIf_test_claimReferralFees_NoWithdrawDuringClaim() public {
        vm.expectRevert(abi.encodeWithSelector(NoWithdrawDuringClaim.selector));
        vm.prank(referrer);
        quest.claimReferralFees(referrer);
    }

    function test_RevertIf_test_claimReferralFees_AlreadyWithdrawn() public {
        vm.warp(START_TIME);
        vm.prank(questFactoryMock);
        quest.claimFromFactory(participant, referrer);

        vm.warp(END_TIME);
        vm.prank(referrer);
        quest.claimReferralFees(referrer);

        vm.expectRevert(abi.encodeWithSelector(AlreadyWithdrawn.selector));
        vm.prank(referrer);
        quest.claimReferralFees(referrer);
    }

    function test_RevertIf_test_claimReferralFees_NoReferralFees() public {
        vm.warp(START_TIME);
        vm.prank(questFactoryMock);
        quest.claimFromFactory(participant, participant);

        vm.expectRevert(abi.encodeWithSelector(NoReferralFees.selector));
        vm.warp(END_TIME);
        vm.prank(referrer);
        quest.claimReferralFees(referrer);
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
            calculateTotalProtocolFees(TOTAL_PARTICIPANTS, REWARD_AMOUNT_IN_WEI, QUEST_FEE),
            "maxProtocolReward should be correct"
        );
    }

    function test_getRewardAmount() public {
        assertEq(quest.getRewardAmount(), REWARD_AMOUNT_IN_WEI, "getRewardAmount should be correct");
    }

    function test_getRewardToken() public {
        assertEq(quest.getRewardToken(), rewardTokenAddress, "getRewardToken should be correct");
    }

    function test_getReferralRewardFee() public {
        assertEq(quest.referralRewardFee(), REFERRAL_REWARD_FEE, "referralRewardFee should be correct");
    }
}
