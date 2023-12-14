// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {JSONParserLib} from "solady/utils/JSONParserLib.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract TestQuestFactory is Test, Errors, Events, TestUtils {
    using LibClone for address;
    using LibString for address;
    using LibString for string;
    using JSONParserLib for string;
    using LibString for uint256;

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
    address anyone = makeAddr(("anyone"));
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
        vm.deal(anyone, 1000000);

        questFactory.initialize(
            claimSigner.addr,
            protocolFeeRecipient,
            address(new Quest()),
            payable(address(new Quest1155())),
            owner,
            defaultReferralFeeRecipient,
            address(new SablierMock()),
            NFT_QUEST_FEE,
            REFERRAL_FEE,
            MINT_FEE
        );
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
            "actionType",
            "questName"
        );

        Quest1155 quest1155 = Quest1155(payable(questAddress));
        assertEq(quest1155.tokenId(), 1, "tokenId should be set");

        vm.stopPrank();
    }

    function test_RevertIf_create1155QuestAndQueue_MsgValueLessThanQuestNFTFee() public {
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
            "actionType",
            "questName"
        );
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
            "actionType",
            "questName"
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
            "actionType",
            "questName"
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
            "actionType",
            "questName"
        );

        vm.expectRevert(abi.encodeWithSelector(QuestIdUsed.selector));
        questFactory.createQuestAndQueue(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "questId",
            "actionType",
            "questName"
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
            "actionType",
            "questName"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function test_claimOptimized_1155_with_ref() public{
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
            "actionType",
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes memory data = abi.encode(participant, referrer, "questId", "json",  address(sampleERC1155), 1);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claimOptimized{value: MINT_FEE}(signature, data);

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
    }

    function test_claimOptimized_erc20_with_ref() public{
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
            "actionType",
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes memory data = abi.encode(participant, referrer, "questId", "json", address(sampleERC20), 1);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        vm.recordLogs();
        questFactory.claimOptimized{value: MINT_FEE}(signature, data);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 5);

        // assert indexed log data
        assertEq(entries[2].topics[0], keccak256("QuestClaimed(address,address,string,address,uint256)"));
        assertEq(entries[2].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[2].topics[2], bytes32(uint256(uint160(questAddress))));

        // assert non-indexed log data
        (string memory questId, address rewardToken, uint256 rewardAmountInWei) = abi.decode(entries[2].data, (string, address, uint256));
        assertEq(questId, string("questId"));
        assertEq(rewardToken, address(sampleERC20));
        assertEq(rewardAmountInWei, REWARD_AMOUNT);

        vm.stopPrank();
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
            "actionType",
            "questName"
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