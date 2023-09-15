// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IQuestTerminalKey {
    // Structs
    struct Discount {
        uint16 percentage; //in BIPS
        uint16 usedCount;
    }

    // Errors
    error ZeroAddress();
    error InvalidDiscountPercentage();
    error NonexistentToken();
    error OnlyMinter();
    error OnlyFactory();

    // Events
    event RoyaltyFeeSet(uint256 indexed royaltyFee);
    event MinterAddressSet(address indexed minterAddress);
    event QuestFactoryAddressSet(address indexed questFactoryAddress);

    // Update Functions
    function initialize(
        address royaltyRecipient_,
        address minterAddress_,
        address questFactoryAddress_,
        uint256 royaltyFee_,
        address owner_,
        string memory imageIPFSHash_,
        string memory animationUrlIPFSHash_
    ) external;

    function setImageIPFSHash(string memory imageIPFSHash_) external;
    function setAnimationUrlIPFSHash(string memory animationUrlIPFSHash_) external;
    function setRoyaltyRecipient(address royaltyRecipient_) external;
    function setMinterAddress(address minterAddress_) external;
    function setQuestFactoryAddress(address questFactoryAddress_) external;
    function setRoyaltyFee(uint256 royaltyFee_) external;
    function mint(address to_, uint16 discountPercentage_) external;
    function bulkMintNoDiscount(address[] memory addresses_) external;
    function incrementUsedCount(uint256 tokenId_) external;

    // Read Functions
    function getOwnedTokenIds(address owner_) external view returns (uint256[] memory);
    function tokenURI(uint256 tokenId_) external view returns (string memory);
    function royaltyInfo(
        uint256 tokenId_,
        uint256 salePrice_
    ) external view returns (address receiver, uint256 royaltyAmount);
    function discounts(uint256 tokenId_) external view returns (uint16 percentage, uint16 usedCount);
}
