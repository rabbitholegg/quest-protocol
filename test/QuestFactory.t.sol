// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract TestQuestFactory is Test, Errors, Events, TestUtils {
    using LibClone for address;

    QuestFactory questFactory;
    SampleERC1155 sampleERC1155;
    SampleERC20 sampleERC20;
    uint256 claimSignerPrivateKey;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint40 DURATION_TOTAL = 10000;
    uint16 REFERRAL_FEE = 2000;
    uint256 NFT_QUEST_FEE = 10;
    uint256 REWARD_AMOUNT = 10;
    uint16 QUEST_FEE = 2000;
    uint256 MINT_FEE = 100;
    address defaultReferralFeeRecipient = makeAddr("defaultReferralFeeRecipient");
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address questCreator = makeAddr(("questCreator"));
    address participant = makeAddr(("participant"));
    address referrer = makeAddr(("referrer"));
    address owner = makeAddr(("owner"));

    function setUp() public {
        address payable questFactoryAddress = payable(address(new QuestFactory()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        questFactory = QuestFactory(questFactoryAddress);

        sampleERC1155 = new SampleERC1155();
        sampleERC20 = new SampleERC20("name", "symbol", 1000000, questCreator);
        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        vm.deal(owner, 1000000);
        vm.deal(participant, 1000000);
        vm.deal(questCreator, 1000000);

        questFactory.initialize(
            claimSigner.addr,
            protocolFeeRecipient,
            address(new Quest()),
            payable(address(new Quest1155())),
            owner,
            defaultReferralFeeRecipient,
            address(new SablierMock()),
            NFT_QUEST_FEE,
            REFERRAL_FEE
        );
        vm.prank(owner);
        questFactory.setMintFee(MINT_FEE); // todo this should be set in initialize
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function test_initialize() public {
        assertEq(protocolFeeRecipient, questFactory.protocolFeeRecipient(), "protocolFeeRecipient not set");
        assertEq(owner, questFactory.owner(), "owner should be set");
        assertEq(defaultReferralFeeRecipient, questFactory.defaultReferralFeeRecipient(), "defaultReferralFeeRecipient should be set");
    }

    /*//////////////////////////////////////////////////////////////
                             CREATE QUESTS
    //////////////////////////////////////////////////////////////*/
    function test_create1155QuestAndQueue() public {
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        address questAddress = questFactory.create1155QuestAndQueue{value: NFT_QUEST_FEE * TOTAL_PARTICIPANTS}(
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "questId",
            "actionSpec"
        );

        Quest1155 quest1155 = Quest1155(payable(questAddress));
        assertEq(quest1155.tokenId(), 1, "tokenId should be set");

        vm.stopPrank();
    }

    function test_RevertIf_reate1155QuestAndQueue_MsgValueLessThanQuestNFTFee() public {
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        vm.expectRevert(abi.encodeWithSelector(MsgValueLessThanQuestNFTFee.selector));
        questFactory.create1155QuestAndQueue{value: NFT_QUEST_FEE * TOTAL_PARTICIPANTS - 1}(
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "questId",
            "actionSpec"
        );
    }

    function test_createERC20StreamQuest() public {
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));

        vm.expectEmit(true,false,true,true);
        emit QuestCreatedWithAction(questCreator, address(0), "questId", "erc20", address(sampleERC20), END_TIME, START_TIME, TOTAL_PARTICIPANTS, REWARD_AMOUNT, "actionSpec");

        address questAddress = questFactory.createERC20StreamQuest(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            DURATION_TOTAL
        );

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.startTime(), START_TIME, "startTime should be set");
        assertEq(quest.durationTotal(), DURATION_TOTAL, "durationTotal should be set");

        vm.stopPrank();
    }

    function test_createQuestAndQueue() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));

        vm.expectEmit(true,false,true,true);
        emit QuestCreated(questCreator, address(0), "questId", "erc20", address(sampleERC20), END_TIME, START_TIME, TOTAL_PARTICIPANTS, REWARD_AMOUNT);

        address questAddress = questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "",
            0
        );

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.startTime(), START_TIME, "startTime should be set");
        assertEq(quest.queued(), true, "queued should be set");
        assertEq(sampleERC20.balanceOf(address(quest)), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE), "balance should be set");

        vm.stopPrank();
    }

    function test_RevertIf_createQuestAndQueue_RewardNotAllowed() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), false);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        vm.expectRevert(abi.encodeWithSelector(RewardNotAllowed.selector));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );
    }

    function test_RevertIf_createQuestAndQueue_QuestIdUsed() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        vm.expectRevert(abi.encodeWithSelector(QuestIdUsed.selector));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );
    }

    function test_RevertIf_createQuestAndQueue_Erc20QuestAddressNotSet() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);
        questFactory.setErc20QuestAddress(address(0));

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));

        vm.expectRevert(abi.encodeWithSelector(Erc20QuestAddressNotSet.selector));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function test_claim_with_claim1155Rewards_with_referrer() public{
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        questFactory.create1155QuestAndQueue{value: NFT_QUEST_FEE * TOTAL_PARTICIPANTS}(
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "questId",
            "actionSpec"
        );

        uint256 questCreatorBeforeBalance = questCreator.balance;
        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId", referrer));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, referrer);

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        // claim fee & nft quset fee rewards
        assertEq(questCreator.balance - questCreatorBeforeBalance, MINT_FEE / 3, "questCreator mint fee");
        assertEq(protocolFeeRecipient.balance, (MINT_FEE / 3) + NFT_QUEST_FEE, "protocolFeeRecipient mint fee");
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
    }

    function test_claim_with_claim1155Rewards_without_referrer() public{
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        questFactory.create1155QuestAndQueue{value: NFT_QUEST_FEE * TOTAL_PARTICIPANTS}(
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "questId",
            "actionSpec"
        );

        uint256 questCreatorBeforeBalance = questCreator.balance;
        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        // claim fee & nft quset fee rewards
        assertEq(questCreator.balance - questCreatorBeforeBalance, MINT_FEE / 3, "questCreator mint fee");
        assertEq(protocolFeeRecipient.balance, (MINT_FEE / 3) * 2 + NFT_QUEST_FEE, "protocolFeeRecipient mint fee");

        vm.stopPrank();
    }

    function test_claim_with_claimRewards_with_referrer() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        uint256 questCreatorBeforeBalance = questCreator.balance;
        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId", referrer));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, referrer);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        // claim fee rewards
        assertEq(questCreator.balance - questCreatorBeforeBalance, MINT_FEE / 3, "questCreator mint fee");
        assertEq(protocolFeeRecipient.balance, MINT_FEE / 3, "protocolFeeRecipient mint fee");
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
    }

    function test_claim_with_claimRewards_without_referrer() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        uint256 questCreatorBeforeBalance = questCreator.balance;
        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        // claim fee rewards
        assertEq(questCreator.balance - questCreatorBeforeBalance, MINT_FEE / 3, "questCreator mint fee");
        assertEq(protocolFeeRecipient.balance, (MINT_FEE / 3) * 2, "protocolFeeRecipient mint fee");

        vm.stopPrank();
    }

    function test_RevertIf_claim_QuestNotStarted() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(QuestNotStarted.selector));
        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));
    }

    function test_RevertIf_claim_InvalidHash() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(InvalidHash.selector));
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));
    }

    function test_RevertIf_claim_AddressAlreadyMinted() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));

        vm.expectRevert(abi.encodeWithSelector(AddressAlreadyMinted.selector));
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));
    }

    function test_RevertIf_claim_QuestEnded() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.warp(END_TIME + 1);
        vm.startPrank(participant);
        vm.expectRevert(abi.encodeWithSelector(QuestEnded.selector));
        questFactory.claim{value: MINT_FEE}("questId", msgHash, signature, address(0));
    }

    function test_RevertIf_claim_InvalidMintFee() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId"));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        vm.expectRevert(abi.encodeWithSelector(InvalidMintFee.selector));
        questFactory.claim{value: MINT_FEE -1}("questId", msgHash, signature, address(0));
    }

    function test_fuzz_claim(string memory questId_, address ref_, string memory actionSpec_, uint256 total_participants_) public{
        vm.assume(ref_ != address(0));
        total_participants_ = bound(total_participants_, 1, 100);
        sampleERC20.mint(questCreator, REWARD_AMOUNT * total_participants_);

        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(total_participants_, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            total_participants_,
            REWARD_AMOUNT,
            questId_,
            actionSpec_,
            0
        );

        uint256 questCreatorBeforeBalance = questCreator.balance;
        vm.warp(START_TIME + 1);
        bytes32 msgHash = keccak256(abi.encodePacked(participant, questId_, ref_));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: MINT_FEE}(questId_, msgHash, signature, ref_);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        // claim fee rewards
        assertEq(questCreator.balance - questCreatorBeforeBalance, MINT_FEE / 3, "questCreator mint fee");
        assertEq(protocolFeeRecipient.balance, MINT_FEE / 3, "protocolFeeRecipient mint fee");
        assertEq(ref_.balance, MINT_FEE / 3, "referrer mint fee");
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/
    function test_questData() public {
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionSpec",
            0
        );

        IQuestFactory.QuestData memory questData = questFactory.questData("questId");

        assertEq(questData.questAddress, questAddress);
        assertEq(questData.rewardToken, address(sampleERC20));
        assertEq(questData.queued, true);
        assertEq(questData.questFee, QUEST_FEE);
        assertEq(questData.startTime, START_TIME);
        assertEq(questData.endTime, END_TIME);
        assertEq(questData.totalParticipants, TOTAL_PARTICIPANTS);
        assertEq(questData.numberMinted, 0);
        assertEq(questData.redeemedTokens, 0);
        assertEq(questData.rewardAmountOrTokenId, REWARD_AMOUNT);
        assertEq(questData.hasWithdrawn, false);

        vm.stopPrank();
    }
}