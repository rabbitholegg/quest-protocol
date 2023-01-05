// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';
import './DateTime.sol';

contract RabbitHoleReceipt is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    IERC2981Upgradeable,
    DateTime
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;
    CountersUpgradeable.Counter private _tokenIds;

    mapping(uint => string) public questIdForTokenId;
    address public royaltyRecipient;
    address public minterAddress;
    uint public royaltyFee;
    mapping(uint => uint) public timestampForTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address royaltyRecipient_, address minterAddress_, uint royaltyFee_) public initializer {
        __ERC721_init('RabbitHoleReceipt', 'RHR');
        __ERC721URIStorage_init();
        __Ownable_init();
        royaltyRecipient = royaltyRecipient_;
        minterAddress = minterAddress_;
        royaltyFee = royaltyFee_;
    }

    modifier onlyMinter() {
        msg.sender == minterAddress;
        _;
    }

    function setRoyaltyRecipient(address royaltyRecipient_) public onlyOwner {
        royaltyRecipient = royaltyRecipient_;
    }

    function setMinterAddress(address minterAddress_) public onlyOwner {
        minterAddress = minterAddress_;
    }

    function setRoyaltyFee(uint256 _royaltyFee) public onlyOwner {
        royaltyFee = _royaltyFee;
    }

    function _mintSingleNFT(address _to, string memory _questId) private {
        _tokenIds.increment();
        uint newTokenID = _tokenIds.current();
        _safeMint(_to, newTokenID);
        questIdForTokenId[newTokenID] = _questId;
        timestampForTokenId[newTokenID] = block.timestamp;
    }

    function mint(address _to, uint _count, string memory _questId) public onlyMinter {
        for (uint i = 0; i < _count; i++) {
            _mintSingleNFT(_to, _questId);
        }
    }

    function getOwnedTokenIdsOfQuest(
        string memory _questId,
        address claimingAddress
    ) public view returns (uint[] memory) {
        uint msgSenderBalance = balanceOf(claimingAddress);
        uint[] memory tokenIdsForQuest = new uint[](msgSenderBalance);
        uint foundTokens = 0;

        for (uint i = 0; i < msgSenderBalance; i++) {
            uint tokenId = tokenOfOwnerByIndex(claimingAddress, i);
            if (keccak256(bytes(questIdForTokenId[tokenId])) == keccak256(bytes(_questId))) {
                tokenIdsForQuest[i] = tokenId;
                foundTokens++;
            }
        }

        uint[] memory filteredTokens = new uint[](foundTokens);
        uint filterTokensIndexTracker = 0;

        for (uint i = 0; i < msgSenderBalance; i++) {
            if (tokenIdsForQuest[i] > 0) {
                filteredTokens[filterTokensIndexTracker] = tokenIdsForQuest[i];
                filterTokensIndexTracker++;
            }
        }
        return filteredTokens;
    }

    function tokenIdCanClaim(uint _tokenId) public view returns (bool) {
        uint16 year = getYear(timestampForTokenId[_tokenId]);
        uint8 month = getMonth(timestampForTokenId[_tokenId]);
        uint8 day = getDay(timestampForTokenId[_tokenId]);
        uint claimTimestamp = toTimestamp(year, month, day, 0, 0, 0) + 86400;
        return block.timestamp >= claimTimestamp;
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function tokenURI(
        uint _tokenId
    ) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        require(_exists(_tokenId), 'ERC721URIStorage: URI query for nonexistent token');

        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole Quest #',
            questIdForTokenId[_tokenId],
            ' Redeemer #',
            _tokenId.toString(),
            '",',
            '"description": "This is a receipt for a RabbitHole Quest. You can use this receipt to claim a reward on RabbitHole.",',
            '"image": "',
            generateSVG(_tokenId),
            '"',
            '}'
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64Upgradeable.encode(dataURI)));
    }

    function generateSVG(uint _tokenId) public view returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>',
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Quest #',
            questIdForTokenId[_tokenId],
            '</text>',
            '<text x="70%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Quest Receipt #',
            _tokenId,
            '</text>',
            '</svg>'
        );
        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64Upgradeable.encode(svg)));
    }

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId), 'Nonexistent token');

        uint256 royaltyPayment = (salePrice * royaltyFee) / 1000;
        return (royaltyRecipient, royaltyPayment);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }
}
