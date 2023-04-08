// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';
import {OwnableUpgradeable} from './OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import './ReceiptRenderer.sol';
import './interfaces/IQuestFactory.sol';
import './interfaces/IQuest.sol';

contract SoulboundRabbitHoleReceipt is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable
{
    event MinterAddressSet(address indexed minterAddress);

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    // storage
    mapping(uint => string) public questIdForTokenId;
    mapping(uint => uint) public timestampForTokenId;
    address public royaltyRecipient;
    address public minterAddress;
    ReceiptRenderer public ReceiptRendererContract;
    IQuestFactory public QuestFactoryContract;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address receiptRenderer_,
        address minterAddress_,
        address owner_
    ) external initializer {
        __ERC721_init('SoulboundRabbitHoleReceipt', 'RHR');
        __ERC721URIStorage_init();
        __Ownable_init(owner_);
        minterAddress = minterAddress_;
        ReceiptRendererContract = ReceiptRenderer(receiptRenderer_);
    }

    modifier onlyMinter() {
        require(msg.sender == minterAddress, 'Only minter');
        _;
    }

    /// @dev set the receipt renderer contract
    /// @param receiptRenderer_ the address of the receipt renderer contract
    function setReceiptRenderer(address receiptRenderer_) external onlyOwner {
        ReceiptRendererContract = ReceiptRenderer(receiptRenderer_);
    }

    /// @dev set the quest factory contract
    /// @param questFactory_ the address of the quest factory contract
    function setQuestFactory(address questFactory_) external onlyOwner {
        QuestFactoryContract = IQuestFactory(questFactory_);
    }

    /// @dev set the minter address
    /// @param minterAddress_ the address of the minter
    function setMinterAddress(address minterAddress_) external onlyOwner {
        minterAddress = minterAddress_;
        emit MinterAddressSet(minterAddress_);
    }

    /// @dev mint a receipt
    /// @param to_ the address to mint to
    /// @param questId_ the quest id
    function mint(address to_, string memory questId_) external onlyMinter {
        _tokenIds.increment();
        uint newTokenID = _tokenIds.current();
        questIdForTokenId[newTokenID] = questId_;
        timestampForTokenId[newTokenID] = block.timestamp;
        _safeMint(to_, newTokenID);
    }

    /// @dev return the token uri, this delegates to the receipt renderer contract
    function tokenURI(
        uint tokenId_
    ) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        require(_exists(tokenId_), 'ERC721URIStorage: URI query for nonexistent token');
        require(QuestFactoryContract != IQuestFactory(address(0)), 'QuestFactory not set');

        string memory questId = questIdForTokenId[tokenId_];
        (address questAddress, uint totalParticipants, ) = QuestFactoryContract.questInfo(questId);
        IQuest questContract = IQuest(questAddress);

        bool claimed = questContract.isClaimed(tokenId_);
        uint rewardAmount = questContract.getRewardAmount();
        address rewardAddress = questContract.getRewardToken();

        return
            ReceiptRendererContract.generateTokenURI(
                tokenId_,
                questId,
                totalParticipants,
                claimed,
                rewardAmount,
                rewardAddress
            );
    }

    /// @dev get the current token id
    function getTokenId() public view returns (uint) {
        return _tokenIds.current();
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only the owner of the token can burn it.");
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        require(from == address(0) || to == address(0), "This is a Soulbound token. It cannot be transferred. It can only be burned by the token owner.");
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /// @dev returns true if the supplied interface id is supported
    /// @param interfaceId_ the interface id
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return interfaceId_ == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId_);
    }
}
