// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import './TicketRenderer.sol';

contract RabbitHoleTickets is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable, IERC2981Upgradeable {
    // storage
    address public royaltyRecipient;
    address public minterAddress;
    uint public royaltyFee;
    TicketRenderer public TicketRendererContract;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address ticketRenderer_, address royaltyRecipient_, address minterAddress_, uint royaltyFee_) initializer public {
        __ERC1155_init("");
        __Ownable_init();
        __ERC1155Burnable_init();
        royaltyRecipient = royaltyRecipient_;
        minterAddress = minterAddress_;
        royaltyFee = royaltyFee_;
        TicketRendererContract = TicketRenderer(ticketRenderer_);
    }

    modifier onlyMinter() {
        msg.sender == minterAddress;
        _;
    }

    function setTicketRenderer(address ticketRenderer_) public onlyOwner {
        TicketRendererContract = TicketRenderer(ticketRenderer_);
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

    function mint(address to, uint256 id, uint256 amount, bytes memory data)
        public
        onlyMinter
    {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyMinter
    {
        _mintBatch(to, ids, amounts, data);
    }

    function uri(
        uint _tokenId
    ) public view virtual override(ERC1155Upgradeable) returns (string memory) {
        return TicketRendererContract.generateTokenURI(_tokenId);
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
