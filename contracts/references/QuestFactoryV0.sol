// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Inherits
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "../libraries/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create quests and handle claims
// solhint-disable-next-line max-states-count
/// @custom:oz-upgrades-from QuestFactoryV0
contract QuestFactoryV0 is Initializable, OwnableUpgradeable, AccessControlUpgradeable {
    // structs used in mappings
    struct NftQuestFees {
        uint256 fee;
        bool exists;
    }

    struct Quest {
        mapping(address => bool) addressMinted;
        address questAddress;
        uint256 totalParticipants;
        uint256 numberMinted;
        string questType;
        uint40 durationTotal;
        address questCreator;
        address mintFeeRecipient;
    }

    // storage starts here
    address public claimSignerAddress;
    address public protocolFeeRecipient;
    address public erc20QuestAddress;
    address public erc1155QuestAddress;
    mapping(string => Quest) public quests;
    address public rabbitHoleReceiptContract;
    address public rabbitHoleTicketsContract;
    mapping(address => bool) public rewardAllowlist;
    uint16 public questFee;
    uint256 public mintFee;
    address public mintFeeRecipient;
    uint256 private locked;
    address private questTerminalKeyContract;
    uint256 public nftQuestFee;
    address public questNFTAddress;
    mapping(address => address[]) public ownerCollections;
    mapping(address => NftQuestFees) public nftQuestFeeList;
    uint16 public referralFee;
    address public sablierV2LockupLinearAddress;
    mapping(address => address) public mintFeeRecipientList;
}
