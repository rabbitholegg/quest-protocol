// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';

contract RabbitHoleTickets is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable, IERC2981Upgradeable {
    using StringsUpgradeable for uint256;

    // storage
    mapping(uint => string) public questIdForTokenId;
    address public royaltyRecipient;
    address public minterAddress;
    uint public royaltyFee;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address royaltyRecipient_, address minterAddress_, uint royaltyFee_) initializer public {
        __ERC1155_init("");
        __Ownable_init();
        __ERC1155Burnable_init();
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

    function setRoyaltyFee(uint256 _royaltyFee) public onlyOwner {
        royaltyFee = _royaltyFee;
    }

    function setMinterAddress(address minterAddress_) public onlyOwner {
        minterAddress = minterAddress_;
    }

    function mint(string memory _questId, address to, uint256 id, uint256 amount, bytes memory data)
        public
        onlyMinter
    {
        setIdForQuestId(_questId, id);
        _mint(to, id, amount, data);
    }

    function mintBatch(string[] memory questIds, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyMinter
    {
        for(uint i = 0; i < ids.length; i++) {
          setIdForQuestId(questIds[i], ids[i]);
        }
        _mintBatch(to, ids, amounts, data);
    }

    function setIdForQuestId(string memory _questId, uint256 id) internal {
        if(bytes(questIdForTokenId[id]).length == 0) {
            questIdForTokenId[id] = _questId;
        }
    }

    function uri(
        uint _tokenId
    ) public view virtual override(ERC1155Upgradeable) returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole Tickets #',
            questIdForTokenId[_tokenId],
            ' Redeemer #',
            _tokenId.toString(),
            '",',
            '"description": "A reward for completing quests within RabbitHole, with unk(no)wn utility",',
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
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Tickets #',
            questIdForTokenId[_tokenId],
            '</text>',
            '<text x="70%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Tickets Receipt #',
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
        uint256 royaltyPayment = (salePrice * royaltyFee) / 1000;
        return (royaltyRecipient, royaltyPayment);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }
}
