// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';
import {OwnableUpgradeable} from './OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract QuestTerminalKey is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    IERC2981Upgradeable
{
    event RoyaltyFeeSet(uint256 indexed royaltyFee);
    event MinterAddressSet(address indexed minterAddress);
    event QuestFactoryAddressSet(address indexed questFactoryAddress);

    using CountersUpgradeable for CountersUpgradeable.Counter;
    using Strings for uint256;
    using Strings for uint16;

    // storage
    CountersUpgradeable.Counter private _tokenIds;
    address public royaltyRecipient;
    address public minterAddress;
    address public questFactoryAddress;
    uint public royaltyFee;
    mapping(uint256 => Discount) public discounts;
    struct Discount {
        uint16 percentage; //in BIPS
        uint16 maxUses;
        uint16 usedCount;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address royaltyRecipient_,
        address minterAddress_,
        address questFactoryAddress_,
        uint royaltyFee_,
        address owner_
    ) external initializer {
        __ERC721_init('QuestTerminalKey', 'QTK');
        __ERC721URIStorage_init();
        __Ownable_init(owner_);
        royaltyRecipient = royaltyRecipient_;
        minterAddress = minterAddress_;
        questFactoryAddress = questFactoryAddress_;
        royaltyFee = royaltyFee_;
    }

    modifier onlyMinter() {
        require(msg.sender == minterAddress, 'Only minter');
        _;
    }

    modifier onlyQuestFactory() {
        require(msg.sender == questFactoryAddress, 'Only quest factory');
        _;
    }

    /// @dev modifier to check for zero address
    /// @param _address the address to check
    modifier nonZeroAddress(address _address) {
        require(_address != address(0), 'Zero address');
        _;
    }

    /// @dev set the royalty recipient
    /// @param royaltyRecipient_ the address of the royalty recipient
    function setRoyaltyRecipient(address royaltyRecipient_) external nonZeroAddress(royaltyRecipient_) onlyOwner {
        royaltyRecipient = royaltyRecipient_;
    }

    /// @dev set the minter address
    /// @param minterAddress_ the address of the minter
    function setMinterAddress(address minterAddress_) external nonZeroAddress(minterAddress_) onlyOwner {
        minterAddress = minterAddress_;
        emit MinterAddressSet(minterAddress_);
    }

    /// @dev set the quest factory address
    /// @param questFactoryAddress_ the address of the quest factory
    function setQuestFactoryAddress(address questFactoryAddress_) external nonZeroAddress(questFactoryAddress_) onlyOwner {
        questFactoryAddress = questFactoryAddress_;
        emit QuestFactoryAddressSet(questFactoryAddress_);
    }

    /// @dev set the royalty fee
    /// @param royaltyFee_ the royalty fee
    function setRoyaltyFee(uint256 royaltyFee_) external onlyOwner {
        royaltyFee = royaltyFee_;
        emit RoyaltyFeeSet(royaltyFee_);
    }

    /// @dev mint a QuestTerminalKey NFT
    /// @param to_ the address to mint to
    /// @param discountPercentage_ the discount percentage
    /// @param maxDiscountUses_ the max discount uses
    function mint(address to_, uint16 discountPercentage_, uint16 maxDiscountUses_) external onlyMinter {
        require(discountPercentage_ <= 10000, 'Invalid discount percentage');
        require(maxDiscountUses_ <= 1000, 'Invalid max discount uses');

        _tokenIds.increment();
        uint tokenId = _tokenIds.current();
        discounts[tokenId] = Discount(discountPercentage_, maxDiscountUses_, 0);
        _safeMint(to_, tokenId);
    }

    /// @dev increment used count
    /// @param tokenId_ the token id
    function incrementUsedCount(uint tokenId_) external onlyQuestFactory {
        discounts[tokenId_].usedCount++;
    }

    /// @dev get the owned token ids of an address
    /// @param owner_ the address to get the token ids of
    function getOwnedTokenIds(address owner_) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner_);
        uint256[] memory tokenIds = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner_, i);
        }

        return tokenIds;
    }

    /// @dev before token transfer hook
    /// @param from the address from
    /// @param to the address to
    /// @param tokenId the token id
    /// @param batchSize the batch size
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /// @dev burn a token
    /// @param tokenId the token id
    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    /// @dev returns the token uri
    /// @param tokenId_ the token id
    function tokenURI(uint256 tokenId_)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        bytes memory dataURI = generateDataURI(tokenId_);
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    /// @dev returns the data uri in json format
    /// @param tokenId_ the token id
    function generateDataURI(
        uint tokenId_
    ) internal view virtual returns (bytes memory) {
        string memory tokenIdString = tokenId_.toString();

        bytes memory attributes = abi.encodePacked(
            '[',
            generateAttribute('Discount Percentage BPS', discounts[tokenId_].percentage.toString()),
            ',',
            generateAttribute('Discount Max Uses', discounts[tokenId_].maxUses.toString()),
            ',',
            generateAttribute('Discount Used Count', discounts[tokenId_].usedCount.toString()),
            ']'
        );
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole.gg QuestTerminalKey #',
            tokenIdString,
            '",',
            '"description": "The RabbitHole.gg QuestTerminalKey is used as key to access the Terminal.",',
            '"image": "',
            "https://rabbithole.gg/_next/image?url=%2FQTKNFT.png",
            '",',
            '"attributes": ',
            attributes,
            '}'
        );
        return dataURI;
    }

    /// @dev generates an attribute object for an ERC-721 token
    /// @param key The key for the attribute
    /// @param value The value for the attribute
    function generateAttribute(string memory key, string memory value) internal pure returns (string memory) {
        bytes memory attribute = abi.encodePacked(
            '{',
            '"trait_type": "',
            key,
            '",',
            '"value": "',
            value,
            '"',
            '}'
        );
        return string(attribute);
    }

    /// @dev See {IERC165-royaltyInfo}
    /// @param tokenId_ the token id
    /// @param salePrice_ the sale price
    function royaltyInfo(
        uint256 tokenId_,
        uint256 salePrice_
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId_), 'Nonexistent token');

        uint256 royaltyPayment = (salePrice_ * royaltyFee) / 10_000;
        return (royaltyRecipient, royaltyPayment);
    }

    /// @dev returns true if the supplied interface id is supported
    /// @param interfaceId_ the interface id
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId_ == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId_);
    }
}
