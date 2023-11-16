// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
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
    uint16 QUEST_FEE = 2000; // 20%
    uint256 MINT_FEE = 100;
    uint256 MINT_AMOUNT = 100_000;
    uint256 LARGE_ETH_AMOUNT = 100_000_000;
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address questFactoryMock;
    address participant = makeAddr("participant");
    address owner = makeAddr("owner");
    address referrer = makeAddr("referrer");
    Vm.Wallet claimSigner = vm.createWallet("claimSigner");
    uint256 claimSignerPrivateKey = claimSigner.privateKey;

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
            protocolFeeRecipient,
            claimSigner.addr
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
        assertEq(QUEST_FEE, quest.questFee(), "questFee not set");
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
            QUEST_FEE,
            protocolFeeRecipient,
            claimSigner.addr
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
            protocolFeeRecipient,
            claimSigner.addr
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
        // transfer out the token it has from setUp
        vm.prank(address(quest));
        SampleERC1155(sampleERC1155).safeTransferFrom(address(quest), protocolFeeRecipient, TOKEN_ID, MINT_AMOUNT, "0x0");

        vm.expectRevert(abi.encodeWithSelector(InsufficientTokenBalance.selector));
        vm.prank(questFactoryMock);
        quest.queue();
    }

    function test_RevertIf_not_enough_eth() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientETHBalance.selector));
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

        uint256 protocolFeeRecipientOGBalance = protocolFeeRecipient.balance;
        vm.prank(questFactoryMock);
        quest.singleClaim(participant);

        assertEq(
            protocolFeeRecipient.balance,
            protocolFeeRecipientOGBalance + QUEST_FEE,
            "participant should have received the reward in ETH"
        );
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

    function test_RevertIf_singleClaim_whenNotPaused() public {
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
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
        vm.deal(address(quest), LARGE_ETH_AMOUNT);
        vm.prank(questFactoryMock);
        quest.transferOwnership(owner);
        vm.prank(owner);
        quest.queue();

        uint256 ownerOGBalance = owner.balance;
        vm.warp(END_TIME + 1);
        vm.prank(protocolFeeRecipient);

        quest.withdrawRemainingTokens();
        assertEq(
            owner.balance,
            ownerOGBalance + LARGE_ETH_AMOUNT,
            "owner should have received remaining ETH"
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

    function test_RevertIf_withdrawRemainingToken_NotQueued() public {
        vm.expectRevert(abi.encodeWithSelector(NotQueued.selector));
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
            quest.maxProtocolReward(), TOTAL_PARTICIPANTS * QUEST_FEE,
            "maxProtocolReward should be correct"
        );
    }
}
