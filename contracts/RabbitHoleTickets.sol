// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {Base64} from "solady/src/utils/Base64.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    IERC165Upgradeable,
    IERC2981Upgradeable
} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

contract RabbitHoleTickets is Initializable, Ownable, ERC1155, IERC2981Upgradeable {
    error OnlyMinter();

    event RoyaltyFeeSet(uint256 indexed royaltyFee);
    event MinterAddressSet(address indexed minterAddress);

    // storage
    address public royaltyRecipient;
    address public minterAddress;
    uint256 public royaltyFee;
    string public imageIPFSCID;
    string public animationUrlIPFSCID;

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address royaltyRecipient_,
        address minterAddress_,
        uint256 royaltyFee_,
        address owner_,
        string memory imageIPFSCID_,
        string memory animationUrlIPFSCID_
    ) external initializer {
        _initializeOwner(owner_);
        royaltyRecipient = royaltyRecipient_;
        minterAddress = minterAddress_;
        royaltyFee = royaltyFee_;
        imageIPFSCID = imageIPFSCID_;
        animationUrlIPFSCID = animationUrlIPFSCID_;
    }

    modifier onlyMinter() {
        if (msg.sender != minterAddress) revert OnlyMinter();
        _;
    }

    /// @dev set the image IPFS CID
    /// @param imageIPFSCID_ the image IPFS CID
    function setImageIPFSCID(string memory imageIPFSCID_) external onlyOwner {
        imageIPFSCID = imageIPFSCID_;
    }

    /// @dev set the animation url IPFS CID
    /// @param animationUrlIPFSCID_ the animation url IPFS CID
    function setAnimationUrlIPFSCID(string memory animationUrlIPFSCID_) external onlyOwner {
        animationUrlIPFSCID = animationUrlIPFSCID_;
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
        _batchMint(to_, ids_, amounts_, data_);
    }

    /// @dev returns the token uri
    function uri(uint256) public view override (ERC1155) returns (string memory) {
        bytes memory dataURI = generateDataURI();
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    /// @dev returns the data uri in json format
    function generateDataURI() internal view virtual returns (bytes memory) {
        // solhint-disable quotes
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "',
            "RabbitHole Ticket",
            '",',
            '"description": "',
            "RabbitHole Tickets",
            '",',
            '"image": "',
            tokenImage(imageIPFSCID),
            '",',
            '"animation_url": "',
            animationUrl(animationUrlIPFSCID),
            '"',
            "}"
        );
        // solhint-enable quotes
        return dataURI;
    }

    function tokenImage(string memory imageIPFSCID_) internal view virtual returns (string memory) {
        return string(abi.encodePacked("ipfs://", imageIPFSCID_));
    }

    function animationUrl(string memory animationUrlIPFSCID_) internal view virtual returns (string memory) {
        if (bytes(animationUrlIPFSCID_).length == 0) {
            return "";
        }
        return string(abi.encodePacked("ipfs://", animationUrlIPFSCID_));
    }

    /// @dev See {IERC165-royaltyInfo}
    /// @param salePrice_ the sale price
    function royaltyInfo(
        uint256,
        uint256 salePrice_
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        uint256 royaltyPayment = (salePrice_ * royaltyFee) / 10_000;
        return (royaltyRecipient, royaltyPayment);
    }

    /// @dev returns true if the supplied interface id is supported
    /// @param interfaceId_ the interface id
    function supportsInterface(bytes4 interfaceId_)
        public
        view
        virtual
        override (ERC1155, IERC165Upgradeable)
        returns (bool)
    {
        return interfaceId_ == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId_);
    }
}
