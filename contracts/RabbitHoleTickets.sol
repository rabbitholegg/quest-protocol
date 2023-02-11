// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import './TicketRenderer.sol';

contract RabbitHoleTickets is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ERC1155BurnableUpgradeable,
    IERC2981Upgradeable
{
    event RoyaltyFeeSet(uint256 indexed royaltyFee);
    event MinterAddressSet(address indexed minterAddress);

    using CountersUpgradeable for CountersUpgradeable.Counter;

    // storage
    address public royaltyRecipient;
    address public minterAddress;
    uint public royaltyFee;
    TicketRenderer public TicketRendererContract;
    CountersUpgradeable.Counter private _tokenIds;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address ticketRenderer_,
        address royaltyRecipient_,
        address minterAddress_,
        uint royaltyFee_
    ) external initializer {
        __ERC1155_init('');
        __Ownable_init();
        __ERC1155Burnable_init();
        royaltyRecipient = royaltyRecipient_;
        minterAddress = minterAddress_;
        royaltyFee = royaltyFee_;
        TicketRendererContract = TicketRenderer(ticketRenderer_);
    }

    modifier onlyMinter() {
        require(msg.sender == minterAddress, "Only minter");
        _;
    }

    /// @dev set the ticket renderer contract
    /// @param ticketRenderer_ the address of the ticket renderer contract
    function setTicketRenderer(address ticketRenderer_) external onlyOwner {
        TicketRendererContract = TicketRenderer(ticketRenderer_);
    }

    /// @dev set the royalty recipient
    /// @param royaltyRecipient_ the address of the royalty recipient
    function setRoyaltyRecipient(address royaltyRecipient_) external onlyOwner {
        royaltyRecipient = royaltyRecipient_;
    }

    /// @dev set the royalty fee
    /// @param royaltyFee_ the royalty fee
    function setRoyaltyFee(uint256 royaltyFee_) external onlyOwner {
        royaltyFee = royaltyFee_;
        emit RoyaltyFeeSet(royaltyFee_);
    }

    /// @dev set the minter address
    /// @param minterAddress_ the address of the minter
    function setMinterAddress(address minterAddress_) external onlyOwner {
        minterAddress = minterAddress_;
        emit MinterAddressSet(minterAddress_);
    }

    /// @dev mint a single ticket, only callable by the allowed minter
    /// @param to_ the address to mint the ticket to
    /// @param id_ the id of the ticket to mint
    /// @param amount_ the amount of the ticket to mint
    /// @param data_ the data to pass to the mint function
    function mint(address to_, uint256 id_, uint256 amount_, bytes memory data_) external onlyMinter {
        _mint(to_, id_, amount_, data_);
    }

    /// @dev mint a batch of tickets, only callable by the allowed minter
    /// @param to_ the address to mint the tickets to
    /// @param ids_ the ids of the tickets to mint
    /// @param amounts_ the amounts of the tickets to mint
    /// @param data_ the data to pass to the mint function
    function mintBatch(
        address to_,
        uint256[] memory ids_,
        uint256[] memory amounts_,
        bytes memory data_
    ) external onlyMinter {
        _mintBatch(to_, ids_, amounts_, data_);
    }

    /// @dev return the uri, this delegates to the ticket renderer contract
    function uri(uint tokenId_) public view virtual override(ERC1155Upgradeable) returns (string memory) {
        return TicketRendererContract.generateTokenURI(tokenId_);
    }

    /// @dev See {IERC165-royaltyInfo}
    /// @param tokenId_ the token id
    /// @param salePrice_ the sale price
    function royaltyInfo(
        uint256 tokenId_,
        uint256 salePrice_
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        uint256 royaltyPayment = (salePrice_ * royaltyFee) / 10_000;
        return (royaltyRecipient, royaltyPayment);
    }

    /// @dev returns true if the supplied interface id is supported
    /// @param interfaceId_ the interface id
    function supportsInterface(
        bytes4 interfaceId_
    ) public view virtual override(ERC1155Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId_ == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId_);
    }
}
