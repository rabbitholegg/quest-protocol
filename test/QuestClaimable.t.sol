// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {SampleERC20} from "contracts/test/SampleERC20.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
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
            defaultReferralFeeRecipient,
            address(0),
            NFT_QUEST_FEE,
            REFERRAL_FEE,
            MINT_FEE
        );
    }

    /*//////////////////////////////////////////////////////////////
                             CLAIM ERC20
    //////////////////////////////////////////////////////////////*/
    function test_claim_with_referrer() public {
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);

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
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[101],"questName":"questName","actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimSignerPrivateKey, digest);
        if (v != 27) { s = s | bytes32(uint256(1) << 255); }

        bytes memory data = abi.encodePacked(txHash, r, s, referrer); // this trims all zeros
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant);
        vm.recordLogs();
        (bool success, ) = questAddress.call{value: MINT_FEE}(payload);
        require(success, "erc20 questAddress.call failed");

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 5);

        bytes32 questAddressBytes = bytes32(uint256(uint160(questAddress)));
        // assert indexed log data for entries[1]
        assertEq(entries[1].topics[0], keccak256("QuestClaimedData(address,address,string)"));
        assertEq(entries[1].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[1].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[1]
        (string memory jsonLog) = abi.decode(entries[1].data, (string));
        assertEq(jsonLog, json);

        // assert indexed log data for entries[2]
        assertEq(entries[2].topics[0], keccak256("QuestClaimed(address,address,string,address,uint256)"));
        assertEq(entries[2].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[2].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[2]
        (string memory questIdLog, address rewardToken, uint256 rewardAmountInWei) = abi.decode(entries[2].data, (string, address, uint256));
        assertEq(questIdLog, string("550e8400-e29b-41d4-a716-446655440000"));
        assertEq(rewardToken, address(sampleERC20));
        assertEq(rewardAmountInWei, REWARD_AMOUNT);

        vm.stopPrank();
    }

    function test_claim_without_referrer() public {
        vm.startPrank(owner);
        questFactory.setRewardAllowlistAddress(address(sampleERC20), true);
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
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x001975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[101],"questName":"questName","actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimSignerPrivateKey, digest);
        if (v != 27) { s = s | bytes32(uint256(1) << 255); }

        bytes memory data = abi.encodePacked(txHash, r, s);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant);
        vm.recordLogs();
        (bool success, ) = questAddress.call{value: MINT_FEE}(payload);
        require(success, "erc20 questAddress.call failed");

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), REWARD_AMOUNT, "particpiant erc20 balance");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 3);

        bytes32 questAddressBytes = bytes32(uint256(uint160(questAddress)));
        // assert indexed log data for entries[1]
        assertEq(entries[1].topics[0], keccak256("QuestClaimedData(address,address,string)"));
        assertEq(entries[1].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[1].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[1]
        (string memory jsonLog) = abi.decode(entries[1].data, (string));
        assertEq(jsonLog, json);

        // assert indexed log data for entries[2]
        assertEq(entries[2].topics[0], keccak256("QuestClaimed(address,address,string,address,uint256)"));
        assertEq(entries[2].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[2].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[2]
        (string memory questIdLog, address rewardToken, uint256 rewardAmountInWei) = abi.decode(entries[2].data, (string, address, uint256));
        assertEq(questIdLog, string("550e8400-e29b-41d4-a716-446655440000"));
        assertEq(rewardToken, address(sampleERC20));
        assertEq(rewardAmountInWei, REWARD_AMOUNT);

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
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[7777777],"questName":"questName","actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimSignerPrivateKey, digest);
        if (v != 27) { s = s | bytes32(uint256(1) << 255); }

        bytes memory data = abi.encodePacked(txHash, r, s, referrer);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant);
        vm.recordLogs();
        (bool success, ) = questAddress.call{value: MINT_FEE}(payload);
        require(success, "1155 questAddress.call failed");

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
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
            "questName"
        );

        vm.warp(START_TIME + 1);

        bytes32 txHash = hex'7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516';
        string memory json = '{"actionTxHashes":["0x7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[7777777],"questName":"questName","actionType":"actionType"}';
        bytes memory signData = abi.encode(participant, referrer, "550e8400-e29b-41d4-a716-446655440000", json);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimSignerPrivateKey, digest);
        if (v != 27) { s = s | bytes32(uint256(1) << 255); }

        bytes memory data = abi.encodePacked(txHash, r, s);
        bytes memory payload = abi.encodePacked(abi.encodeWithSignature("claim()"), data);

        vm.startPrank(participant);
        vm.recordLogs();
        (bool success, ) = questAddress.call{value: MINT_FEE}(payload);
        require(success, "1155 questAddress.call failed");

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");
    }

}
