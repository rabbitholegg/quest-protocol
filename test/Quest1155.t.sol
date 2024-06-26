// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract TestQuest1155 is Test, Errors, Events, TestUtils {
    using LibClone for address;
    using LibString for uint256;

    Quest1155 quest;
    address sampleERC1155;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 TOKEN_ID = 1;
    uint256 CLAIM_FEE = 999;
    uint16 QUEST_FEE = 2000; // 20%
    uint256 MINT_FEE = 99;
    uint256 MINT_AMOUNT = 100_000;
    uint256 LARGE_ETH_AMOUNT = 100_000_000;
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address questFactoryMock;
    address participant = makeAddr("participant");
    address owner = makeAddr("owner");

    function setUp() public {
        questFactoryMock = address(new QuestFactoryMock());
        sampleERC1155 = address(new SampleERC1155());
        address payable questAddress = payable(address(new Quest1155()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest1155(questAddress);
        vm.prank(questFactoryMock);

        quest.initialize(
            sampleERC1155,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            TOKEN_ID,
            protocolFeeRecipient,
            "questId"
        );

        SampleERC1155(sampleERC1155).mintSingle(address(quest), TOKEN_ID, MINT_AMOUNT);

        vm.warp(START_TIME + 1);
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function test_initialize() public {
        assertEq(sampleERC1155, quest.rewardToken(), "rewardTokenAddress not set");
        assertEq(END_TIME, quest.endTime(), "endTime not set");
        assertEq(START_TIME, quest.startTime(), "startTime not set");
        assertEq(TOTAL_PARTICIPANTS, quest.totalParticipants(), "totalParticipants not set");
        assertEq(TOKEN_ID, quest.tokenId(), "tokenId not set");
        assertEq(protocolFeeRecipient, quest.protocolFeeRecipient(), "protocolFeeRecipient not set");
        assertEq(questFactoryMock, quest.owner(), "owner should be set");
    }

    function test_RevertIf_initialize_EndTimeInPast() public {
        vm.warp(END_TIME + 1);
        questFactoryMock = address(new QuestFactoryMock());
        sampleERC1155 = address(new SampleERC1155());
        address payable questAddress = payable(address(new Quest1155()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest1155(questAddress);
        vm.prank(questFactoryMock);

        vm.expectRevert(abi.encodeWithSelector(EndTimeInPast.selector));
        quest.initialize(
            sampleERC1155,
            END_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            TOKEN_ID,
            protocolFeeRecipient,
            "questId"
        );
    }

    function test_RevertIf_initialize_EndTimeLessThanOrEqualToStartTime() public {
        vm.warp(START_TIME - 1); // reset time
        questFactoryMock = address(new QuestFactoryMock());
        sampleERC1155 = address(new SampleERC1155());
        address payable questAddress = payable(address(new Quest1155()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        quest = Quest1155(questAddress);
        vm.prank(questFactoryMock);

        vm.expectRevert(abi.encodeWithSelector(EndTimeLessThanOrEqualToStartTime.selector));
        quest.initialize(
            sampleERC1155,
            START_TIME,
            START_TIME,
            TOTAL_PARTICIPANTS,
            TOKEN_ID,
            protocolFeeRecipient,
            "questId"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSE
    //////////////////////////////////////////////////////////////*/
    function test_cancel() public {
        vm.prank(questFactoryMock);
        quest.cancel();
        assertTrue(quest.paused(), "paused should be true");
        assertEq(quest.endTime(), block.timestamp + 15 minutes, "endTime should be 15 minutes from now");
    }

    function test_cancel_notStarted() public {
        vm.warp(START_TIME - 1);
        vm.prank(questFactoryMock);
        quest.cancel();
        assertEq(quest.endTime(), block.timestamp, "endTime should be now");
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

    // /*//////////////////////////////////////////////////////////////
    //                            QUEUE
    // //////////////////////////////////////////////////////////////*/

    function test_RevertIf_not_enough_tokens() public {
        // transfer out the token it has from setUp
        vm.prank(address(quest));
        SampleERC1155(sampleERC1155).safeTransferFrom(address(quest), protocolFeeRecipient, TOKEN_ID, MINT_AMOUNT, "0x0");

        vm.expectRevert(abi.encodeWithSelector(InsufficientTokenBalance.selector));
        vm.prank(questFactoryMock);
        quest.queue();
    }

    function test_queue() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);

        vm.prank(questFactoryMock);
        quest.queue();
        assertTrue(quest.queued(), "queued should be true");
    }

    /*//////////////////////////////////////////////////////////////
                            SINGLECLAIM
    //////////////////////////////////////////////////////////////*/

    function test_singleClaim() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
        vm.prank(questFactoryMock);
        quest.queue();

        vm.prank(questFactoryMock);
        quest.singleClaim(participant);

        assertEq(
            SampleERC1155(sampleERC1155).balanceOf(participant, TOKEN_ID),
            1,
            "participant should have received the reward in ERC1155"
        );
    }

    // todo add fuzz test

    function test_RevertIf_singleClaim_NotQuestFactory() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
        vm.prank(questFactoryMock);
        quest.queue();

        vm.expectRevert(abi.encodeWithSelector(NotQuestFactory.selector));
        quest.singleClaim(participant);
    }

    function test_RevertIf_singleClaim_NotStarted() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
        vm.prank(questFactoryMock);
        quest.queue();

        vm.warp(START_TIME - 1);
        vm.prank(questFactoryMock);
        vm.expectRevert(abi.encodeWithSelector(NotStarted.selector));
        quest.singleClaim(participant);
    }

    // /*//////////////////////////////////////////////////////////////
    //                   WITHDRAWREMAININGTOKENS
    // //////////////////////////////////////////////////////////////*/

    function test_withdrawRemainingTokens() public {
        QuestFactoryMock(questFactoryMock).setMintFee(CLAIM_FEE);
        QuestFactoryMock(questFactoryMock).setNumberMinted(TOTAL_PARTICIPANTS);

        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);

        // simulate ETH from TOTAL_PARTICIPANTS claims
        vm.deal(address(quest), (CLAIM_FEE * TOTAL_PARTICIPANTS * 2) / 3);

        vm.warp(END_TIME + 1);
        vm.prank(protocolFeeRecipient);

        quest.withdrawRemainingTokens();

        assertEq(
            owner.balance,
            CLAIM_FEE * TOTAL_PARTICIPANTS * 1 / 3,
            "owner should have received (claimFee * redeemedTokens) / 3 eth"
        );
        assertEq(
            protocolFeeRecipient.balance,
            CLAIM_FEE * TOTAL_PARTICIPANTS * 1 / 3,
            "protocolFeeRecipient should have received remaining ETH"
        );
        assertEq(
            SampleERC1155(sampleERC1155).balanceOf(owner, TOKEN_ID),
            MINT_AMOUNT,
            "owner should have received remaining ERC1155"
        );
    }

    // todo add fuzz test

    function test_RevertIf_withdrawRemainingToken_NotEnded() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);
        vm.prank(owner);
        quest.queue();

        vm.expectRevert(abi.encodeWithSelector(NotEnded.selector));
        vm.prank(protocolFeeRecipient);
        quest.withdrawRemainingTokens();
    }

    function test_RevertIf_withdrawRemainingToken_AlreadyWithdrawn() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);
        vm.prank(owner);
        quest.queue();

        vm.warp(END_TIME + 1);
        vm.prank(protocolFeeRecipient);

        quest.withdrawRemainingTokens();

        vm.expectRevert(abi.encodeWithSelector(AlreadyWithdrawn.selector));
        quest.withdrawRemainingTokens();
    }

    // /*//////////////////////////////////////////////////////////////
    //                         EXTERNAL VIEW
    // //////////////////////////////////////////////////////////////*/

    function test_maxProtocolReward() public {
        assertEq(
            quest.maxProtocolReward(), TOTAL_PARTICIPANTS,
            "maxProtocolReward should be correct"
        );
    }
}
