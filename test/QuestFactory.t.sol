// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
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
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint16 REFERRAL_FEE = 2000;
    uint256 NFT_QUEST_FEE = 10;
    uint16 QUEST_FEE = 2000;
    uint256 REWARD_AMOUNT = 10;
    uint40 DURATION_TOTAL = 10000;
    address defaultReferralFeeRecipient = makeAddr("defaultReferralFeeRecipient");
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address participant = makeAddr(("participant"));
    address referrer = makeAddr(("referrer"));
    address owner = makeAddr(("owner"));

    function setUp() public {
        address payable questFactoryAddress = payable(address(new QuestFactory()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        questFactory = QuestFactory(questFactoryAddress);

        sampleERC1155 = new SampleERC1155();
        sampleERC20 = new SampleERC20("name", "symbol", 1000000, owner);
        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        vm.deal(owner, 1000000);
        vm.deal(participant, 1000000);

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
        vm.startPrank(owner);
        sampleERC1155.mintSingle(owner, 1, TOTAL_PARTICIPANTS);
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

    function test_createERC20StreamQuest() public {
        vm.startPrank(owner);

        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));

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

        vm.stopPrank();
    }

    function test_createQuestAndQueue() public{
        vm.startPrank(owner);

        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);
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

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.startTime(), START_TIME, "startTime should be set");
        assertEq(quest.queued(), true, "queued should be set");
        assertEq(sampleERC20.balanceOf(address(quest)), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE), "balance should be set");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function test_claim_with_claim1155Rewards() public{
        vm.startPrank(owner);

        sampleERC1155.mintSingle(owner, 1, TOTAL_PARTICIPANTS);
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
        vm.warp(START_TIME + 1);

        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId", referrer));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: NFT_QUEST_FEE}("questId", msgHash, signature, referrer);

        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        vm.stopPrank();
    }

    function test_claim_with_claimRewards() public{
        vm.startPrank(owner);

        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);
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

        bytes32 msgHash = keccak256(abi.encodePacked(participant, "questId", referrer));
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant);
        questFactory.claim{value: QUEST_FEE}("questId", msgHash, signature, referrer);

        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        vm.stopPrank();
    }
}