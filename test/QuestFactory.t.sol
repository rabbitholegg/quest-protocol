// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

// solhint-disable no-global-import, no-console
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
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {JSONParserLib} from "solady/utils/JSONParserLib.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {QuestData} from "./helpers/QuestData.sol";
 
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
    uint16 REFERRAL_FEE = 2000;
    uint256 NFT_QUEST_FEE = 10;
    uint16 QUEST_FEE = 2000;
    uint256 MINT_FEE = 100;
    QuestData.MockQuestData QUEST = QuestData.MockQuestData({
        END_TIME : 1_000_000_000,
        START_TIME : 1_000_000,
        TOTAL_PARTICIPANTS : 300,
        REWARD_AMOUNT : 10_000_000_000,
        QUEST_ID_STRING :  "550e8400-e29b-41d4-a716-446655440000",
        QUEST_ID : hex'550e8400e29b41d4a716446655440000',
        ACTION_TYPE: "actionType",
        QUEST_NAME: "questName",
        PROJECT_NAME: "projectName",
        CHAIN_ID : 7777777,
        TX_HASH : hex'7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516',
        JSON_MSG : '{"actionTxHashes":["0x7e1975a6bf513022a8cc382a3cdb1e1dbcd58ebb1cb9abf11e64aadb21262516"],"actionNetworkChainIds":[7777777],"actionType":"actionType"}',
        REFERRAL_REWARD_FEE: 500
    });
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
        sampleERC20 = new SampleERC20("name", "symbol", calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE), questCreator);
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
                              INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function test_initialize() public {
        assertEq(protocolFeeRecipient, questFactory.protocolFeeRecipient(), "protocolFeeRecipient not set");
        assertEq(owner, questFactory.owner(), "owner should be set");
    }

    /*//////////////////////////////////////////////////////////////
                             CREATE QUESTS
    //////////////////////////////////////////////////////////////*/
    function test_createERC1155Quest() public {
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, QUEST.TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        address questAddress = questFactory.createERC1155Quest(
            address(sampleERC1155),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            1,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME
        );

        Quest1155 quest1155 = Quest1155(payable(questAddress));
        assertEq(quest1155.tokenId(), 1, "tokenId should be set");

        vm.stopPrank();
    }

    function test_createERC20Quest() public{
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));

        vm.expectEmit(true,false,true,true);
        emit QuestCreated(questCreator, address(0), QUEST.PROJECT_NAME, QUEST.QUEST_NAME, QUEST.QUEST_ID_STRING, "erc20", QUEST.ACTION_TYPE, QUEST.CHAIN_ID, address(sampleERC20), QUEST.END_TIME, QUEST.START_TIME, QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT);

        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.startTime(), QUEST.START_TIME, "startTime should be set");
        assertEq(quest.queued(), true, "queued should be set");
        assertEq(sampleERC20.balanceOf(address(quest)), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE), "balance should be set");

        vm.stopPrank();
    }

    function test_RevertIf_createERC20Quest_QuestIdUsed() public{
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.expectRevert(abi.encodeWithSelector(QuestIdUsed.selector));
        questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );
    }

    function test_RevertIf_createERC20Quest_Erc20QuestAddressNotSet() public{
        vm.startPrank(owner);
        questFactory.setErc20QuestAddress(address(0));

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));

        vm.expectRevert(abi.encodeWithSelector(Erc20QuestAddressNotSet.selector));
        questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function test_claimCompressed_1155_with_ref() public{
        vm.startPrank(questCreator);

        sampleERC1155.mintSingle(questCreator, 1, QUEST.TOTAL_PARTICIPANTS);
        sampleERC1155.setApprovalForAll(address(questFactory), true);

        questFactory.createERC1155Quest(
            QUEST.CHAIN_ID,
            address(sampleERC1155),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            1,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME
        );

        vm.warp(QUEST.START_TIME + 1);

        bytes memory signData = abi.encode(participant, referrer, QUEST.QUEST_ID_STRING, QUEST.JSON_MSG);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        bytes memory data = abi.encode(QUEST.TX_HASH, r, vs, referrer, QUEST.QUEST_ID, QUEST.CHAIN_ID);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(participant, participant);
        questFactory.claimCompressed{value: MINT_FEE}(dataCompressed);

        // 1155 reward
        assertEq(sampleERC1155.balanceOf(participant, 1), 1, "particpiant erc1155 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
    }

    function test_claimCompressed_erc20_mocked_data() public{
        bytes memory signData = abi.encode(participant, referrer, QUEST.QUEST_ID_STRING, QUEST.JSON_MSG);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        vm.deal(participant, 1000000);
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING, 
            QUEST.ACTION_TYPE, 
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.warp(QUEST.START_TIME + 1);

        bytes memory data = abi.encode(QUEST.TX_HASH, r, vs, referrer, QUEST.QUEST_ID, QUEST.CHAIN_ID);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(participant, participant);
        questFactory.claimCompressed{value: MINT_FEE}(dataCompressed);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), QUEST.REWARD_AMOUNT, "particpiant erc20 balance");

        // referrer claimable amount
        assertEq(Quest(payable(questAddress)).getReferralAmount(referrer), Quest(payable(questAddress)).referralRewardAmount());
    }

    function test_claimCompressedRef_erc20_mocked_data() public{
        bytes memory signData = abi.encode(participant, referrer, QUEST.QUEST_ID_STRING, QUEST.JSON_MSG);
        
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        vm.deal(participant, 1000000);

        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING, 
            QUEST.ACTION_TYPE, 
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.warp(QUEST.START_TIME + 1);

        bytes memory data = abi.encode(QUEST.TX_HASH, r, vs, referrer, QUEST.QUEST_ID, QUEST.CHAIN_ID);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(anyone, anyone);
        questFactory.claimCompressedRef{value: MINT_FEE}(dataCompressed, participant);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), QUEST.REWARD_AMOUNT, "particpiant erc20 balance");

        // referrer claimable amount
        assertEq(Quest(payable(questAddress)).getReferralAmount(referrer), Quest(payable(questAddress)).referralRewardAmount());
    }

    function test_claimCompressed_erc20_with_ref() public{
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.warp(QUEST.START_TIME + 1);
     
        bytes memory signData = abi.encode(participant, referrer, QUEST.QUEST_ID_STRING, QUEST.JSON_MSG);
        bytes32 msgHash = keccak256(signData);
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (, bytes32 r, bytes32 vs) = TestUtils.getSplitSignature(claimSignerPrivateKey, digest);

        bytes memory data = abi.encode(QUEST.TX_HASH, r, vs, referrer, QUEST.QUEST_ID, QUEST.CHAIN_ID);
        bytes memory dataCompressed = LibZip.cdCompress(data);

        vm.startPrank(participant, participant);
        vm.recordLogs();
        questFactory.claimCompressed{value: MINT_FEE}(dataCompressed);

        // erc20 reward
        assertEq(sampleERC20.balanceOf(participant), QUEST.REWARD_AMOUNT, "particpiant erc20 balance");

        // referrer payout
        assertEq(referrer.balance, MINT_FEE / 3, "referrer mint fee");
        
        // referrer claimable amount
        assertEq(Quest(payable(questAddress)).getReferralAmount(referrer), Quest(payable(questAddress)).referralRewardAmount());

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 5);

        bytes32 questAddressBytes = bytes32(uint256(uint160(questAddress)));
        // assert indexed log data for entries[1]
        assertEq(entries[1].topics[0], keccak256("QuestClaimedData(address,address,string)"));
        assertEq(entries[1].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[1].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[1]
        (string memory jsonLog) = abi.decode(entries[1].data, (string));
        assertEq(jsonLog, QUEST.JSON_MSG);

        // assert indexed log data for entries[2]
        assertEq(entries[2].topics[0], keccak256("QuestClaimed(address,address,string,address,uint256)"));
        assertEq(entries[2].topics[1], bytes32(uint256(uint160(participant))));
        assertEq(entries[2].topics[2], questAddressBytes);

        // assert non-indexed log data for entries[2]
        (string memory questIdLog, address rewardToken, uint256 rewardAmountInWei) = abi.decode(entries[2].data, (string, address, uint256));
        assertEq(questIdLog, QUEST.QUEST_ID_STRING);
        assertEq(rewardToken, address(sampleERC20));
        assertEq(rewardAmountInWei, QUEST.REWARD_AMOUNT);

        vm.stopPrank();
    }

    function test_claimOptimized_revert_deprecated() public{
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.warp(QUEST.START_TIME + 1);

        bytes memory data = abi.encode(participant, referrer, QUEST.QUEST_ID_STRING, "json", address(sampleERC20), 1);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        vm.startPrank(participant, participant);
        vm.expectRevert(abi.encodeWithSelector(IQuestFactory.Deprecated.selector));
        questFactory.claimOptimized{value: MINT_FEE}(signature, data);
    }

    /*//////////////////////////////////////////////////////////////
                                CANCEL
    //////////////////////////////////////////////////////////////*/

    function test_cancelQuest() public {
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.startPrank(questCreator);
        questFactory.cancelQuest(QUEST.QUEST_ID_STRING);

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.paused(), true, "quest should be paused");
        assertEq(quest.endTime(), block.timestamp, "endTime should be now");
    }

    function test_cancelQuest_alreadyStarted() public {
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.warp(QUEST.START_TIME + 1);
        vm.startPrank(questCreator);
        questFactory.cancelQuest(QUEST.QUEST_ID_STRING);

        Quest quest = Quest(payable(questAddress));
        assertEq(quest.paused(), true, "quest should be paused");
        assertEq(quest.endTime(), block.timestamp + 15 minutes, "endTime should be 15 minutes from now");
    }

    function test_cancelQuest_unauthorized() public {
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        vm.startPrank(anyone);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        questFactory.cancelQuest(QUEST.QUEST_ID_STRING);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/
    function test_questData() public {
        vm.startPrank(questCreator);
        sampleERC20.approve(address(questFactory), calculateTotalRewardsPlusFee(QUEST.TOTAL_PARTICIPANTS, QUEST.REWARD_AMOUNT, QUEST_FEE));
        address questAddress = questFactory.createERC20Quest(
            QUEST.CHAIN_ID,
            address(sampleERC20),
            QUEST.END_TIME,
            QUEST.START_TIME,
            QUEST.TOTAL_PARTICIPANTS,
            QUEST.REWARD_AMOUNT,
            QUEST.QUEST_ID_STRING,
            QUEST.ACTION_TYPE,
            QUEST.QUEST_NAME,
            QUEST.PROJECT_NAME,
            QUEST.REFERRAL_REWARD_FEE
        );

        IQuestFactory.QuestData memory questData = questFactory.questData(QUEST.QUEST_ID_STRING);

        assertEq(questData.questAddress, questAddress);
        assertEq(questData.rewardToken, address(sampleERC20));
        assertEq(questData.queued, true);
        assertEq(questData.questFee, QUEST_FEE);
        assertEq(questData.startTime, QUEST.START_TIME);
        assertEq(questData.endTime, QUEST.END_TIME);
        assertEq(questData.totalParticipants, QUEST.TOTAL_PARTICIPANTS);
        assertEq(questData.numberMinted, 0);
        assertEq(questData.redeemedTokens, 0);
        assertEq(questData.rewardAmountOrTokenId, QUEST.REWARD_AMOUNT);
        assertEq(questData.hasWithdrawn, false);

        vm.stopPrank();
    }
}