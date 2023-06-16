// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import {ERC1155SupplyUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import {SafeERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title QuestNFT
/// @author RabbitHole.gg
/// @notice This contract is the Erc721 Quest Completion contract. It is the NFT that can be minted after a quest is completed.
contract QuestNFT is Initializable, ERC1155Upgradeable, ERC1155SupplyUpgradeable, PausableUpgradeable, OwnableUpgradeable, IERC2981Upgradeable, ReentrancyGuardUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeERC20 for IERC20;

    CountersUpgradeable.Counter private _tokenIdCounter;
    address public protocolFeeRecipient;
    address public minterAddress;
    string public collectionName;
    struct QuestData {
        uint256 endTime;
        uint256 startTime;
        uint256 totalParticipants;
        uint256 questFee;
        uint256 tokenId;
        string imageIPFSHash;
        string description;
    }
    mapping(string => QuestData) public quests; // questId => QuestData
    mapping(uint256 => string) public tokenIdToQuestId; // tokenId => questId

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address protocolFeeRecipient_,
        address minterAddress_, // should always be the QuestFactory contract
        string memory collectionName_
    ) external initializer {
        protocolFeeRecipient = protocolFeeRecipient_;
        minterAddress = minterAddress_;
        collectionName = collectionName_;
        __ERC1155_init("");
        __ERC1155Supply_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    function addQuest(
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        string memory questId_,
        uint256 questFee_,
        string memory description_,
        string memory imageIPFSHash_
    ) public onlyMinter {
        require (endTime_ > block.timestamp, 'endTime_ in past');
        require (startTime_ > block.timestamp, 'startTime_ in past');
        require (endTime_ > startTime_, 'startTime_ before endTime_');

        _tokenIdCounter.increment();
        QuestData storage quest = quests[questId_];
        quest.endTime = endTime_;
        quest.startTime = startTime_;
        quest.totalParticipants = totalParticipants_;
        quest.questFee = questFee_;
        quest.imageIPFSHash = imageIPFSHash_;
        quest.description = description_;
        quest.tokenId = _tokenIdCounter.current();
        tokenIdToQuestId[_tokenIdCounter.current()] = questId_;
    }

    function mint(address to_, string memory questId_)
        public
        onlyMinter onlyQuestBetweenStartEnd(questId_) whenNotPaused nonReentrant
    {
        QuestData storage quest = quests[questId_];
        _mint(to_, quest.tokenId, 1, "");

        (bool success, ) = protocolFeeRecipient.call{value: quest.questFee}("");
        require(success, 'protocol fee transfer failed');
    }

    /// @notice Prevents reward withdrawal until the Quest has ended
    modifier onlyAfterQuestEnd(string memory questId_) {
        QuestData storage quest = quests[questId_];
        require (block.timestamp > quest.endTime, 'Quest has not ended');
        _;
    }

    /// @notice Checks if quest has started from the start time
    modifier onlyQuestBetweenStartEnd(string memory questId_) {
        QuestData storage quest = quests[questId_];
        require(block.timestamp > quest.startTime, 'Quest not started');
        require(block.timestamp < quest.endTime, 'Quest ended');
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minterAddress, 'Only minter address');
        _;
    }

    /// @dev The maximum amount of coins the quest needs for the protocol fee
    function totalTransferAmount(string memory questId_) external view returns (uint256) {
        QuestData storage quest = quests[questId_];
        return quest.questFee * quest.totalParticipants;
    }

    /// @notice Pauses the Quest
    /// @dev Only the owner of the Quest can call this function.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the Quest
    /// @dev Only the owner of the Quest can call this function.
    function unPause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /// @dev Function that to withdraw the remaining coins in the contract to the owner
    /// @notice This function can only be called after the quest end time
    function withdrawRemainingCoins(string memory questId_) external onlyAfterQuestEnd(questId_) nonReentrant {
        uint balance = address(this).balance;
        // TODO: this is not correct, we don't want to send the whole balance, just the balance for the specific questId_
        // or we just don't allow to withdraw until all quests are over
        // or balance for a questid would be the number of quest.participants - balanceOf(questId_)
        // assuming that each participant mints 1 questNFT
        if (balance > 0) {
            (bool success, ) = owner().call{value: balance}("");
            require(success, 'withdraw remaining tokens failed');
        }

    }

    /// @dev saftey hatch function to transfer tokens sent to the contract to the contract owner.
    /// @param erc20Address_ The address of the ERC20 token to refund
    function refund(address erc20Address_) external nonReentrant {
        uint erc20Balance = IERC20(erc20Address_).balanceOf(address(this));
        if (erc20Balance > 0) IERC20(erc20Address_).safeTransfer(owner(), erc20Balance);
    }

    /// @dev returns the token uri
    /// @param tokenId_ the token id
    function uri(uint256 tokenId_)
        public
        view
        override(ERC1155Upgradeable)
        returns (string memory)
    {
        bytes memory dataURI = generateDataURI(tokenId_);
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    /// @dev returns the data uri in json format
    function generateDataURI(uint256 tokenId_) internal view virtual returns (bytes memory) {
        QuestData storage quest = quests[tokenIdToQuestId[tokenId_]];
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "',
            collectionName,
            '",',
            '"description": "',
            quest.description,
            '",',
            '"image": "',
            tokenImage(quest.imageIPFSHash),
            '"',
            '}'
        );
        return dataURI;
    }

    function tokenImage(string memory imageIPFSHash_) internal view virtual returns (string memory) {
        return string(abi.encodePacked('ipfs://', imageIPFSHash_));
    }

    /// @dev See {IERC165-royaltyInfo}
    /// @param tokenId_ the token id
    /// @param salePrice_ the sale price
    function royaltyInfo(
        uint256 tokenId_,
        uint256 salePrice_
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(bytes(tokenIdToQuestId[tokenId_]).length != 0, 'Nonexistent token');

        uint256 royaltyPayment = (salePrice_ * 200) / 10_000; // 2% royalty
        return (owner(), royaltyPayment);
    }

    /// @dev returns true if the supplied interface id is supported
    /// @param interfaceId_ the interface id
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC1155Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId_ == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId_);
    }

    // Functions to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
