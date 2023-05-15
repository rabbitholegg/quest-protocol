// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
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
contract QuestNFT is Initializable, ERC721Upgradeable, PausableUpgradeable, OwnableUpgradeable, IERC2981Upgradeable, ReentrancyGuardUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeERC20 for IERC20;

    CountersUpgradeable.Counter private _tokenIdCounter;

    address public protocolFeeRecipient;
    address public minterAddress;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalParticipants;
    uint16 public questFee;
    string public jsonSpecCID;
    string public imageIPFSHash;
    string public description;
    string public questId;

    event JsonSpecCIDSet(string cid);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        string memory questId_,
        uint16 questFee_,
        address protocolFeeRecipient_,
        address minterAdress_, // should always be the QuestFactory contract
        string memory jsonSpecCID_,
        string memory name_,
        string memory symbol_,
        string memory description_,
        string memory imageIPFSHash_
    ) external initializer {
        require (endTime_ > block.timestamp, 'endTime_ in past');
        require (startTime_ > block.timestamp, 'startTime_ in past');
        require (endTime_ > startTime_, 'startTime_ before endTime_');
        endTime = endTime_;
        startTime = startTime_;
        totalParticipants = totalParticipants_;
        questId = questId_;
        questFee = questFee_;
        protocolFeeRecipient = protocolFeeRecipient_;
        jsonSpecCID = jsonSpecCID_;
        minterAddress = minterAdress_;
        imageIPFSHash = imageIPFSHash_;
        description = description_;
        __ERC721_init(name_, symbol_);
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /// @notice Prevents reward withdrawal until the Quest has ended
    modifier onlyAfterQuestEnd() {
        require (block.timestamp > endTime, 'Quest has not ended');
        _;
    }

    /// @notice Checks if quest has started from the start time
    modifier onlyQuestBetweenStartEnd() {
        require(block.timestamp > startTime, 'Quest not started');
        require(block.timestamp < endTime, 'Quest ended');
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minterAddress, 'Only minter address');
        _;
    }

    /// @dev set jsonSpecCID only if its empty
    /// @param jsonSpecCID_ The jsonSpecCID to set
    function setJsonSpecCID(string memory jsonSpecCID_) external onlyOwner {
        require(bytes(jsonSpecCID_).length > 0, 'jsonSpecCID cannot be empty');
        require(bytes(jsonSpecCID).length == 0, 'jsonSpecCID already set');

        jsonSpecCID = jsonSpecCID_;
        emit JsonSpecCIDSet(jsonSpecCID_);
    }

    /// @dev The maximum amount of coins the quest needs for the protocol fee
    function totalTransferAmount() external view returns (uint256) {
        return questFee * totalParticipants;
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

    function safeMint(address to_) public onlyMinter onlyQuestBetweenStartEnd whenNotPaused nonReentrant {
        _tokenIdCounter.increment();
        uint tokenId = _tokenIdCounter.current();
        _safeMint(to_, tokenId);
        protocolFeeRecipient.call{value: questFee}("");
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /// @dev Function that to withdraw the remaining coins in the contract to the owner
    /// @notice This function can only be called after the quest end time
    function withdrawRemainingTokens() external onlyAfterQuestEnd {
        uint balance = address(this).balance;
        if (balance > 0) owner().call{value: balance}("");

    }

    /// @dev saftey hatch function to transfer tokens sent to the contract to the contract owner.
    /// @param erc20Address_ The address of the ERC20 token to refund
    function refund(address erc20Address_) external {
        uint erc20Balance = IERC20(erc20Address_).balanceOf(address(this));
        if (erc20Balance > 0) IERC20(erc20Address_).safeTransfer(owner(), erc20Balance);
    }

    /// @dev returns the token uri
    /// @param tokenId_ the token id
    function tokenURI(uint256 tokenId_)
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        bytes memory dataURI = generateDataURI();
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    /// @dev returns the data uri in json format
    function generateDataURI() internal view virtual returns (bytes memory) {
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "',
            name(),
            '",',
            '"description": "',
            description,
            '",',
            '"image": "',
            tokenImage(),
            '"',
            '}'
        );
        return dataURI;
    }

    function tokenImage() internal view virtual returns (string memory) {
        return string(abi.encodePacked('ipfs://', imageIPFSHash));
    }

    /// @dev get the current token id
    function getTokenId() public view returns (uint) {
        return _tokenIdCounter.current();
    }

    /// @dev See {IERC165-royaltyInfo}
    /// @param tokenId_ the token id
    /// @param salePrice_ the sale price
    function royaltyInfo(
        uint256 tokenId_,
        uint256 salePrice_
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId_), 'Nonexistent token');

        uint256 royaltyPayment = (salePrice_ * 200) / 10_000; // 2% royalty
        return (owner(), royaltyPayment);
    }

    /// @dev returns true if the supplied interface id is supported
    /// @param interfaceId_ the interface id
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC721Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId_ == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId_);
    }

    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}
