// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {Soulbound20 as Soulbound20Contract} from "contracts/Soulbound20.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibZip} from "solady/utils/LibZip.sol";
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
    uint256 SOULBOUND20_CREATE_FEE = 10;
    uint256 REWARD_AMOUNT = 10;
    uint16 QUEST_FEE = 2000;
    uint256 MINT_FEE = 100;
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
        claimSignerPrivateKey = uint256(vm.envUint("TEST_CLAIM_SIGNER_PRIVATE_KEY"));
        vm.deal(owner, 1000000);
        vm.deal(participant, 1000000);
        vm.deal(questCreator, 1000000);
        vm.deal(anyone, 1000000);

        questFactory.initialize(
            vm.addr(claimSignerPrivateKey),
            protocolFeeRecipient,
            address(new Quest()),
            payable(address(new Quest1155())),
            owner,
            address(new Soulbound20Contract()),
            address(new SablierMock()),
            SOULBOUND20_CREATE_FEE,
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
    }


    /*//////////////////////////////////////////////////////////////
                          CREATE Soulbound20
    //////////////////////////////////////////////////////////////*/
    function test_CreateSoulbound20() public {
        uint protocolRecipientOGBalance = protocolFeeRecipient.balance;
        vm.prank(participant);
        address soulbound20Address = questFactory.createSoulbound20{value: SOULBOUND20_CREATE_FEE}("Test", "TST");

        assertEq(protocolFeeRecipient.balance, protocolRecipientOGBalance + SOULBOUND20_CREATE_FEE);
        assertEq(questFactory.soulbound20State(soulbound20Address), 1);
        assertEq(questFactory.soulbound20Creator(soulbound20Address), participant);

        assertEq(Soulbound20Contract(soulbound20Address).name(), "Test");
        assertEq(Soulbound20Contract(soulbound20Address).symbol(), "TST");
        assertEq(Soulbound20Contract(soulbound20Address).owner(), address(questFactory));
    }

    function test_SetSoulbound20AddressState() public {
        uint state = 2;
        vm.prank(participant);
        address soulbound20Address = questFactory.createSoulbound20{value: SOULBOUND20_CREATE_FEE}("Test", "TST");

        vm.prank(owner);
        questFactory.setSoulbound20AddressState(soulbound20Address, state);

        assertEq(questFactory.soulbound20State(soulbound20Address), state);
    }

    function test_SetSoulbound20CreateFee() public {
        uint soulbound20CreateFee = 1 ether;

        vm.prank(owner);
        questFactory.setSoulbound20CreateFee(soulbound20CreateFee);

        assertEq(questFactory.soulbound20CreateFee(), soulbound20CreateFee);
    }

    function test_createERC20PointsQuest() public {
        vm.startPrank(questCreator);
        address soulbound20Address = questFactory.createSoulbound20{value: SOULBOUND20_CREATE_FEE}("Test", "TST");

        vm.expectEmit(true,false,false,true);
        emit QuestCreated(questCreator, address(0), "questId", "erc20Points", soulbound20Address, END_TIME, START_TIME, 0, REWARD_AMOUNT);

        address questAddress = questFactory.createERC20PointsQuest(
            101,
            soulbound20Address,
            END_TIME,
            START_TIME,
            REWARD_AMOUNT,
            "questId",
            "actionType",
            "questName"
        );

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.startTime(), START_TIME, "startTime should be set");
        assertEq(quest.queued(), true, "queued should be set");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             CREATE QUESTS
    //////////////////////////////////////////////////////////////*/
    function test_createERC1155Quest() public {
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        address questAddress = questFactory.createERC1155Quest(
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

    function test_createERC20Quest() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));

        vm.expectEmit(true,false,false,true);
        emit QuestCreated(questCreator, address(0), "questId", "erc20", address(sampleERC20), END_TIME, START_TIME, TOTAL_PARTICIPANTS, REWARD_AMOUNT);

        address questAddress = questFactory.createERC20Quest(
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

    function test_RevertIf_createERC20Quest_RewardNotAllowed() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), false);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        vm.expectRevert(abi.encodeWithSelector(RewardNotAllowed.selector));
        questFactory.createERC20Quest(
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

    function test_RevertIf_createERC20Quest_QuestIdUsed() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createERC20Quest(
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
        questFactory.createERC20Quest(
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

    function test_RevertIf_createERC20Quest_Erc20QuestAddressNotSet() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);
        questFactory.setErc20QuestAddress(address(0));

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));

        vm.expectRevert(abi.encodeWithSelector(Erc20QuestAddressNotSet.selector));
        questFactory.createERC20Quest(
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
    function test_claimCompressed_1155_with_ref() public{
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        questFactory.createERC1155Quest(
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "550e8400-e29b-41d4-a716-446655440000",
            "actionType",
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes16 questId = hex'550e8400e29b41d4a716446655440000';
        bytes32 txHash = hex'7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        uint32 txHashChainId = 7777777;
        string memory json = '{"actionTxHashes":["0x7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[7777777],"questName":"questName","actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimSignerPrivateKey, digest);
        if (v != 27) { s = s | bytes32(uint256(1) << 255); }

        bytes memory data = abi.encode(txHash, r, s, referrer, questId, txHashChainId);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(participant, participant);
        questFactory.claimCompressed{value: MINT_FEE}(dataCompressed);

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
    }

    function test_claimCompressed_erc20_mocked_data() public{
        address participantMocked = 0xde967dd32C1d057B368ea9F37d70469Cd7F6bF38;
        address referrerMocked = address(0);
        bytes32 txHash = 0x57498a77018f78c02a0e2f0d0e4a8aab048b6e249ff936d230b7db7ca48782e1;
        uint32 txHashChainId = 1;
        bytes16 questId = 0x88e08cb195e64832845fa92ec8f2034a;
        string memory questIdString = "88e08cb1-95e6-4832-845f-a92ec8f2034a";
        string memory actionType = "other";
        string memory questName = "Advanced Trading with dYdX";
        bytes32 r = 0x12a1078fd9cf9bbed1fa8f00b9abd75baa6c07073706479ca25ec34f4043b327;
        bytes32 vs = 0x5aca8bfe397d45aa673c07d2ce845cb4419eadc0cbe8977de337799a37b2e1a3;

        vm.deal(participantMocked, 1000000);
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        questFactory.createERC20Quest(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            questIdString,
            actionType,
            questName
        );

        vm.warp(START_TIME + 1);

        bytes memory data = abi.encode(txHash, r, vs, referrerMocked, questId, txHashChainId);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(participantMocked, participantMocked);
        questFactory.claimCompressed{value: MINT_FEE}(dataCompressed);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participantMocked), REWARD_AMOUNT, "particpiant erc20 balance");
    }

    function test_claimCompressed_erc20_with_ref() public{
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "550e8400-e29b-41d4-a716-446655440000",
            "actionType",
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes16 questId = hex'550e8400e29b41d4a716446655440000';
        bytes32 txHash = hex'001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        uint32 txHashChainId = 101;
        string memory json = '{"actionTxHashes":["0x001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[101],"questName":"questName","actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimSignerPrivateKey, digest);
        if (v != 27) {
            s = s | bytes32(uint256(1) << 255);
        }

        bytes memory data = abi.encode(txHash, r, s, referrer, questId, txHashChainId);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(participant, participant);
        vm.recordLogs();
        questFactory.claimCompressed{value: MINT_FEE}(dataCompressed);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 8);

        bytes32 questAddressBytes = bytes32(uint256(uint160(questAddress)));
        // assert indexed log data for entries[5]
        assertEq(entries[5].topics[0], keccak256("QuestClaimedData(address,address,string)"));
        assertEq(entries[5].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[5].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[5]
        (string memory jsonLog) = abi.decode(entries[5].data, (string));
        assertEq(jsonLog, json);

        // assert indexed log data for entries[6]
        assertEq(entries[6].topics[0], keccak256("QuestClaimed(address,address,string,address,uint256)"));
        assertEq(entries[6].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[6].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[6]
        (string memory questIdLog, address rewardToken, uint256 rewardAmountInWei) = abi.decode(entries[6].data, (string, address, uint256));
        assertEq(questIdLog, string("550e8400-e29b-41d4-a716-446655440000"));
        assertEq(rewardToken, address(sampleERC20));
        assertEq(rewardAmountInWei, REWARD_AMOUNT);

        vm.stopPrank();
    }

    function test_claimOptimized_1155_with_ref() public{
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        questFactory.createERC1155Quest(
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
        address questAddress = questFactory.createERC20Quest(
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
        assertEq(entries.length, 8);

        // assert indexed log data
        assertEq(entries[6].topics[0], keccak256("QuestClaimed(address,address,string,address,uint256)"));
        assertEq(entries[6].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[6].topics[2], bytes32(uint256(uint160(questAddress))));

        // assert non-indexed log data
        (string memory questId, address rewardToken, uint256 rewardAmountInWei) = abi.decode(entries[6].data, (string, address, uint256));
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
        address questAddress = questFactory.createERC20Quest(
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