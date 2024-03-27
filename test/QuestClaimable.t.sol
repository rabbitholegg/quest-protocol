// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

// solhint-disable no-global-import
import "forge-std/Test.sol";

import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {JSONParserLib} from "solady/utils/JSONParserLib.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract TestQuestClaimable is Test, Errors, Events, TestUtils {
    using LibClone for address;
    using LibString for *;
    using JSONParserLib for string;

    QuestFactory questFactory;
    SampleERC1155 sampleERC1155;
    SampleERC20 sampleERC20;
    uint256 claimSignerPrivateKey;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint16 REFERRAL_FEE = 2000;
    uint256 NFT_QUEST_FEE = 10;
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
            NFT_QUEST_FEE,
            REFERRAL_FEE,
            MINT_FEE
        );
    }

    /*//////////////////////////////////////////////////////////////
                             CLAIM ERC20
    //////////////////////////////////////////////////////////////*/
    function test_claim_with_referrer() public {
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            101,
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "550e8400-e29b-41d4-a716-446655440000",
            "actionType",
            "questName",
            "projectName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[101],"actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        bytes memory data = abi.encodePacked(txHash, r, vs, referrer);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant, participant);
        vm.recordLogs();
        vm.expectRevert(IQuestFactory.Deprecated.selector);
        (bool success, ) = questAddress.call{value: MINT_FEE}(payload);
        assertFalse(success, "claim failed");
        vm.stopPrank();
    }

    function test_claim_without_referrer() public {
        referrer = address(0);
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(TOTAL_PARTICIPANTS, REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            101,
            address(sampleERC20),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            REWARD_AMOUNT,
            "550e8400-e29b-41d4-a716-446655440000",
            "actionType",
            "questName",
            "projectName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[101],"actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        bytes memory data = abi.encodePacked(txHash, r, vs);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant, participant);
        vm.recordLogs();
        vm.expectRevert(IQuestFactory.Deprecated.selector);
        (bool success, ) = questAddress.call{value: MINT_FEE}(payload);
        assertFalse(success, "claim failed");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             CLAIM ERC1155
    //////////////////////////////////////////////////////////////*/
    function test_claim_1155_with_ref() public{
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        address questAddress = questFactory.createERC1155Quest{value: NFT_QUEST_FEE * TOTAL_PARTICIPANTS}(
            7777777,
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "550e8400-e29b-41d4-a716-446655440000",
            "actionType",
            "questName",
            "projectName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[7777777],"actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        bytes memory data = abi.encodePacked(txHash, r, vs, referrer);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant, participant);
        vm.recordLogs();
        vm.expectRevert(IQuestFactory.Deprecated.selector);
        vm.stopPrank();
    }

    function test_claim_1155_without_ref() public{
        vm.startPrank(questCreator);
        referrer = address(0);

        sampleERC1155.mintSingle(questCreator, 1, TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        address questAddress = questFactory.createERC1155Quest{value: NFT_QUEST_FEE * TOTAL_PARTICIPANTS}(
            7777777,
            address(sampleERC1155),
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            1,
            "550e8400-e29b-41d4-a716-446655440000",
            "actionType",
            "questName",
            "projectName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[7777777],"actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        bytes memory data = abi.encodePacked(txHash, r, vs);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant, participant);
        vm.recordLogs();
        vm.expectRevert(IQuestFactory.Deprecated.selector);
        vm.stopPrank();
    }

}