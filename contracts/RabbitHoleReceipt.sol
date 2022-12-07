// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract RabbitHoleReceipt is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable, IERC2981Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;
    CountersUpgradeable.Counter private _tokenIds;

    mapping(uint => uint) public questIdForTokenId;
    address public royaltyRecipient;
    address public minterAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address royaltyRecipient_, address minterAddress_) initializer public {
        __ERC721_init("RabbitHoleReceipt", "RHR");
        __ERC721URIStorage_init();
        __Ownable_init();
        royaltyRecipient = royaltyRecipient_;
        minterAddress = minterAddress_;
    }

    function _mintSingleNFT(uint _questId) private {
        _tokenIds.increment();
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender, newTokenID);
        questIdForTokenId[newTokenID] = _questId;
    }

    modifier onlyMinter() {
        msg.sender == minterAddress;
        _;
    }

    function mint(uint _count, uint _questId) onlyMinter public {
        for (uint i = 0; i < _count; i++) {
            _mintSingleNFT(_questId);
        }
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "RabbitHole Quest #', questIdForTokenId[_tokenId].toString() ,' Redeemer #', _tokenId.toString(), '",',
                '"description": "This is a receipt for a RabbitHole Quest. You can use this receipt to claim a reward on RabbitHole.",',
                '"image": "', generateSVG(), '"',
            '}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64Upgradeable.encode(dataURI)
            )
        );
    }

    function generateSVG() public pure returns(string memory){
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>',
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">',"RabbitHole Quest Receipt",'</text>',
            '</svg>'
        );
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64Upgradeable.encode(svg)
            )
        );
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        uint256 royaltyPayment = (salePrice * 10) / 1000; // 10% royalty
        return (royaltyRecipient, royaltyPayment);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
