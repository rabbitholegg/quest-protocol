// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";

contract TestQuest1155 is Test, Errors, Events {
    using LibClone for address;
    using LibString for uint256;

    Quest1155 quest;
    address sampleERC1155;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 TOKEN_ID = 1;
    uint16 QUEST_FEE = 2000; // 20%
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address questFactoryMock;
    address participant = makeAddr(("participant"));

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
            QUEST_FEE,
            protocolFeeRecipient
        );

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
        assertEq(QUEST_FEE, quest.questFee(), "questFee not set");
        assertEq(protocolFeeRecipient, quest.protocolFeeRecipient(), "protocolFeeRecipient not set");
        assertEq(address(questFactoryMock), quest.owner(), "owner should be set");
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
            QUEST_FEE,
            protocolFeeRecipient
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
            QUEST_FEE,
            protocolFeeRecipient
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

    // /*//////////////////////////////////////////////////////////////
    //                            QUEUE
    // //////////////////////////////////////////////////////////////*/

    function test_RevertIf_not_enough_tokens() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientTokenBalance.selector));
        vm.prank(questFactoryMock);
        quest.queue();
    }

    function test_RevertIf_not_enough_eth() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);

        vm.expectRevert(abi.encodeWithSelector(InsufficientETHBalance.selector));
        vm.prank(questFactoryMock);
        quest.queue();
    }

    function test_queue() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);
        vm.deal(address(quest), 100000000);

        vm.prank(questFactoryMock);
        quest.queue();
        assertTrue(quest.queued(), "queued should be true");
    }


    /*//////////////////////////////////////////////////////////////
                            SINGLECLAIM
    //////////////////////////////////////////////////////////////*/

    function test_singleClaim() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);
        vm.deal(address(quest), 100000000);
        vm.prank(questFactoryMock);
        quest.queue();

        // emit ClaimedSingle(account_, rewardToken, 1);
        vm.expectEmit(true, true, false, false, address(quest));
        emit ClaimedSingle(participant, address(sampleERC1155), TOKEN_ID);

        uint256 protocolFeeRecipientOGBalance = protocolFeeRecipient.balance;
        vm.prank(questFactoryMock);
        quest.singleClaim(participant);

        assertEq(
            protocolFeeRecipient.balance,
            protocolFeeRecipientOGBalance + QUEST_FEE,
            "participant should have received the reward"
        );
        assertEq(
            SampleERC1155(sampleERC1155).balanceOf(participant, TOKEN_ID),
            1,
            "participant should have received the reward"
        );
    }

    // todo add fuzz test

    function test_RevertIf_singleClaim_NotQuestFactory() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);
        vm.deal(address(quest), 100000000);
        vm.prank(questFactoryMock);
        quest.queue();

        vm.expectRevert(abi.encodeWithSelector(NotQuestFactory.selector));
        quest.singleClaim(participant);
    }

    function test_RevertIf_singleClaim_NotStarted() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);
        vm.deal(address(quest), 100000000);
        vm.prank(questFactoryMock);
        quest.queue();

        vm.warp(START_TIME - 1);
        vm.prank(questFactoryMock);
        vm.expectRevert(abi.encodeWithSelector(NotStarted.selector));
        quest.singleClaim(participant);
    }

    function test_RevertIf_singleClaim_whenNotPaused() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);
        vm.deal(address(quest), 100000000);
        vm.prank(questFactoryMock);
        quest.queue();
        vm.startPrank(questFactoryMock);
        quest.pause();
        vm.warp(START_TIME);
        vm.expectRevert("Pausable: paused");
        quest.singleClaim(participant);
        vm.stopPrank();
    }

    // /*//////////////////////////////////////////////////////////////
    //                   WITHDRAWREMAININGTOKENS
    // //////////////////////////////////////////////////////////////*/

    function test_withdrawRemainingTokens() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100000;
        SampleERC1155(sampleERC1155).batchMint(address(quest), ids, amounts);
        vm.deal(address(quest), 100000000);
        vm.prank(questFactoryMock);
        quest.queue();

        uint256 ownerOGBalance = questFactoryMock.balance;
        vm.warp(END_TIME + 1);
        vm.prank(protocolFeeRecipient);

        quest.withdrawRemainingTokens();
        assertEq(
            questFactoryMock.balance,
            ownerOGBalance + 100000000,
            "owner should have received remaining ETH"
        );
        assertEq(
            SampleERC1155(sampleERC1155).balanceOf(questFactoryMock, TOKEN_ID),
            100000,
            "owner should have received remaining ERC1155"
        );
    }

    // todo add fuzz test

    // function test_RevertIf_withdrawRemainingToken_NoWithdrawDuringClaim() public {
    //     vm.expectRevert(abi.encodeWithSelector(NoWithdrawDuringClaim.selector));
    //     vm.prank(protocolFeeRecipient);
    //     quest.withdrawRemainingTokens();
    // }

    // function test_RevertIf_withdrawRemainingToken_AlreadyWithdrawn() public {
    //     vm.warp(END_TIME);
    //     vm.startPrank(protocolFeeRecipient);
    //     quest.withdrawRemainingTokens();
    //     vm.expectRevert(abi.encodeWithSelector(AlreadyWithdrawn.selector));
    //     quest.withdrawRemainingTokens();
    //     vm.stopPrank();
    // }

    // /*//////////////////////////////////////////////////////////////
    //                         EXTERNAL VIEW
    // //////////////////////////////////////////////////////////////*/

    function test_maxProtocolReward() public {
        assertEq(
            quest.maxProtocolReward(), TOTAL_PARTICIPANTS * QUEST_FEE,
            "maxProtocolReward should be correct"
        );
    }
}
