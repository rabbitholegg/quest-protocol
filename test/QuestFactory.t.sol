// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {SampleERC1155} from "contracts/test/SampleERC1155.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {SablierV2LockupLinearMock as SablierMock} from "./mocks/SablierV2LockupLinearMock.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";

contract TestQuestFactory is Test, Errors, Events {
    using LibClone for address;
    using LibString for uint256;

    QuestFactory questFactory;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint16 REFERRAL_FEE = 2000; // 20%
    uint256 NFT_QUEST_FEE = 10;
    address defaultReferralFeeRecipient = makeAddr("defaultReferralFeeRecipient");
    address claimSigner = makeAddr("claimSigner");
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    address participant = makeAddr(("participant"));
    address owner = makeAddr(("owner"));

    function setUp() public {
        address payable questFactoryAddress = payable(address(new QuestFactory()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT"))));
        questFactory = QuestFactory(questFactoryAddress);

        questFactory.initialize(
            claimSigner,
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
}