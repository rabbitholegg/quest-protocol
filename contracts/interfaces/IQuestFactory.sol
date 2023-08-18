// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuestFactory {
    // Errors
    error AddressAlreadyMinted();
    error AddressNotSigned();
    error AddressZeroNotAllowed();
    error AuthOwnerDiscountToken();
    error Deprecated();
    error Erc20QuestAddressNotSet();
    error InvalidHash();
    error InvalidMintFee();
    error MsgValueLessThanQuestNFTFee();
    error OverMaxAllowedToMint();
    error QuestFeeTooHigh();
    error QuestIdUsed();
    error QuestNotQueued();
    error QuestNotStarted();
    error QuestEnded();
    error QuestTypeNotSupported();
    error Reentrancy();
    error ReferralFeeTooHigh();
    error RewardNotAllowed();
    error ZeroAddressNotAllowed();

    // Structs

    // This struct is used in a mapping - only add new fields to the end
    struct NftQuestFees {
        uint256 fee;
        bool exists;
    }

    // This struct is used in a mapping - only add new fields to the end
    struct Quest {
        mapping(address => bool) addressMinted;
        address questAddress;
        uint256 totalParticipants;
        uint256 numberMinted;
        string questType;
        uint40 durationTotal;
    }

    struct QuestData {
        address questAddress;
        address rewardToken;
        bool queued;
        uint16 questFee;
        uint256 startTime;
        uint256 endTime;
        uint256 totalParticipants;
        uint256 numberMinted;
        uint256 redeemedTokens;
        uint256 rewardAmountOrTokenId;
        bool hasWithdrawn;
        string questType;
        uint40 durationTotal;
    }

    // Events
    event ExtraMintFeeReturned(address indexed recipient, uint256 amount);
    event MintFeeSet(uint256 mintFee);
    event NftQuestFeeListSet(address[] addresses, uint256[] fees);
    event NftQuestFeeSet(uint256 nftQuestFee);
    event Quest1155Claimed(
        address indexed claimer, address questAddress, string questId, address rewardToken, uint256 tokenId
    );
    event QuestClaimed(
        address indexed claimer, address questAddress, string questId, address rewardToken, uint256 rewardAmount
    );
    event QuestClaimedReferred(
        address indexed claimer,
        address questAddress,
        string questId,
        address rewardToken,
        uint256 rewardAmount,
        address referrer,
        uint16 referralFee,
        uint256 mintFee
    );
    event QuestCreated(
        address indexed creator,
        address questAddress,
        string questId,
        string questType,
        address rewardToken,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId
    );
    event QuestCreatedWithAction(
        address indexed creator,
        address questAddress,
        string questId,
        string questType,
        address rewardToken,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId,
        string actionSpec
    );
    event QuestInfo(address questAddress, uint256 totalParticipants, uint256 numberMinted);
    event ReferralFeeSet(uint16 referralFee);
    event SablierV2LockupLinearAddressSet(address sablierV2LockupLinearAddress);

    // Read Functions
    function getAddressMinted(string memory questId_, address address_) external view returns (bool);
    function getMintFeeRecipient() external view returns (address);
    function getNftQuestFee(address address_) external view returns (uint256);
    function getNumberMinted(string memory questId_) external view returns (uint256);
    function questData(string memory questId_) external view returns (QuestData memory);
    function questInfo(string memory questId_) external view returns (address, uint256, uint256);
    function recoverSigner(bytes32 hash_, bytes memory signature_) external view returns (address);
    function totalQuestNFTFee(uint256 totalParticipants_) external view returns (uint256);

    // Update Functions

    // Claim
    function claim(string memory questId_, bytes32 hash_, bytes memory signature_, address ref_) external payable;
    function claim1155Rewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable;
    function claimRewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable;

    // Create
    function create1155QuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 tokenId_,
        string memory questId_,
        string memory actionSpec_
    ) external payable returns (address);

    // Set
    function setClaimSignerAddress(address claimSignerAddress_) external;
    function setErc1155QuestAddress(address erc1155QuestAddress_) external;
    function setErc20QuestAddress(address erc20QuestAddress_) external;
    function setMintFee(uint256 mintFee_) external;
    function setMintFeeRecipient(address mintFeeRecipient_) external;
    function setNftQuestFee(uint256 nftQuestFee_) external;
    function setNftQuestFeeList(address[] calldata toAddAddresses_, uint256[] calldata fees_) external;
    function setProtocolFeeRecipient(address protocolFeeRecipient_) external;
    function setQuestFee(uint16 questFee_) external;
    function setRewardAllowlistAddress(address rewardAddress_, bool allowed_) external;
    function setSablierV2LockupLinearAddress(address sablierV2LockupLinearAddress_) external;
}
