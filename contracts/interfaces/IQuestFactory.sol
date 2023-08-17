// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuestFactory {
    error AddressAlreadyMinted();
    error AddressNotSigned();
    error AddressZeroNotAllowed();
    error AuthOwnerDiscountToken();
    error Erc20QuestAddressNotSet();
    error InvalidHash();
    error OnlyOwnerCanCreate1155Quest();
    error OverMaxAllowedToMint();
    error QuestEnded();
    error QuestFeeTooHigh();
    error QuestIdUsed();
    error QuestNotQueued();
    error QuestNotStarted();
    error QuestTypeInvalid();
    error RewardNotAllowed();
    error ZeroAddressNotAllowed();
    error ReferralFeeTooHigh();
    error MsgValueLessThanQuestNFTFee();
    error Deprecated();
    error QuestTypeNotSupported();
    error Reentrancy();
    error InvalidMintFee();

    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId
    );
    event Quest1155Created(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId
    );
    event QuestCreatedWithAction(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId,
        string actionSpec
    );
    event ReceiptMinted(
        address indexed recipient, address indexed questAddress, uint256 indexed tokenId, string questId
    );
    event QuestNFTMinted(
        address indexed recipient, address indexed questAddress, uint256 indexed tokenId, string questId
    );
    event MintFeeSet(uint256 amount);
    event ReferralFeeSet(uint16 percent);
    event ExtraMintFeeReturned(address indexed recipient, uint256 amount);
    event NftQuestFeeSet(uint256 fee);
    event QuestNFTCreated(address indexed newQuestNFT, address questCreator, string collectionName);
    event QuestClaimed(
        address indexed recipient,
        address indexed questAddress,
        string questId,
        address rewardToken,
        uint256 rewardAmountInWei
    );
    event QuestClaimedReferred(
        address indexed recipient,
        address indexed questAddress,
        string questId,
        address rewardToken,
        uint256 rewardAmountInWeiOrTokenId,
        address referrer,
        uint16 referralFee,
        uint256 mintFeeEthWei
    );
    event Quest1155Claimed(
        address indexed recipient, address indexed questAddress, string questId, address rewardToken, uint256 tokenId
    );
    event NftQuestFeeListSet(address[] addresses, uint256[] fees);
    event SablierV2LockupLinearAddressSet(address sablierV2LockupLinearAddress);

    function questInfo(string memory questId_) external view returns (address, uint256, uint256);
}
