// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IQuestFactory {
    // Errors
    error AddressAlreadyMinted();
    error AddressNotSigned();
    error AddressZeroNotAllowed();
    error AuthOwnerDiscountToken();
    error Deprecated();
    error Erc20QuestAddressNotSet();
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
    error ZeroAddressNotAllowed();
    error QuestAddressMismatch();
    error ClaimFailed();
    error txOriginMismatch();

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
        address questCreator;
        address mintFeeRecipient;
        string actionType;
        string questName;
        uint32 txHashChainId;
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
    }

    struct QuestJsonData {
        string actionType;
        string questName;
        uint32 txHashChainId;
    }

    struct ClaimData {
        string questId;
        bytes32 hashBytes;
        bytes signature;
        address ref;
        address claimer;
        string extraData;
    }

    struct ERC20QuestData {
        uint32 txHashChainId;
        address rewardTokenAddress;
        uint256 endTime;
        uint256 startTime;
        uint256 totalParticipants;
        uint256 rewardAmount;
        string questId;
        string actionType;
        string questName;
        string questType;
        string projectName;
        uint256 referralRewardFee;
    }

    struct ERC1155QuestData {
        uint32 txHashChainId;
        address rewardTokenAddress;
        uint256 endTime;
        uint256 startTime;
        uint256 totalParticipants;
        uint256 tokenId;
        string questId;
        string actionType;
        string questName;
        string projectName;
    }

    // Events
    event ExtraMintFeeReturned(address indexed recipient, uint256 amount);
    event MintFeeSet(uint256 mintFee);
    event NftQuestFeeListSet(address[] addresses, uint256[] fees);
    event NftQuestFeeSet(uint256 nftQuestFee);

    event QuestCancelled(address indexed questAddress, string questId, uint256 endsAt);

    event QuestClaimedData(
        address indexed recipient,
        address indexed questAddress,
        string extraData
    );
    event Quest1155Claimed(
        address indexed recipient,
        address indexed questAddress,
        string questId,
        address rewardToken,
        uint256 tokenId
    );
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
    event QuestClaimReferred(
        address indexed recipient,
        address indexed questAddress,
        string questId,
        address rewardToken,
        uint256 rewardAmountInWeiOrTokenId,
        address referrer,
        uint16 referralFee,
        uint256 mintFeeEthWei,
        uint256 tokenReferralFee,
        uint256 referralClaimAmount
    );
    event MintFeePaid(
        string questId,
        address rabbitHoleAddress,
        uint256 rabbitHoleAmountWei,
        address questCreatorAddress,
        uint256 questCreatorAmountWei,
        address referrerAddress,
        uint256 referrerAmountWei
    );
    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string projectName,
        string questName,
        string questId,
        string questType,
        string actionType,
        uint32 chainId,
        address rewardToken,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId
    );
    event ReferralFeeSet(uint16 percent);

    // Read Functions
    function getAddressMinted(string memory questId_, address address_) external view returns (bool);
    function getNumberMinted(string memory questId_) external view returns (uint256);
    function questData(string memory questId_) external view returns (QuestData memory);
    function questInfo(string memory questId_) external view returns (address, uint256, uint256);
    function recoverSigner(bytes32 hash_, bytes memory signature_) external view returns (address);
    function mintFee() external view returns (uint256);
    function questJsonData(string memory questId_) external view returns (QuestJsonData memory);
    function buildJsonString(
        bytes32 txHash,
        uint32 txHashChainId,
        string memory actionType,
        string memory questName
    ) external pure returns (string memory);
    function questFee() external view returns (uint16);
    
    // Create
    function create1155QuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 tokenId_,
        string memory questId_,
        string memory
    ) external payable returns (address);

    function createERC20Quest(
        uint32 txHashChainId_,
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string calldata questId_,
        string calldata actionType_,
        string calldata questName_,
        string calldata projectName_,
        uint256 referralRewardFee_
    ) external returns (address);


    function claimOptimized(bytes calldata signature_, bytes calldata data_) external payable;

    function cancelQuest(string calldata questId_) external;

    // Set
    function setClaimSignerAddress(address claimSignerAddress_) external;
    function setErc1155QuestAddress(address erc1155QuestAddress_) external;
    function setErc20QuestAddress(address erc20QuestAddress_) external;
    function setMintFee(uint256 mintFee_) external;
    function setDefaultMintFeeRecipient(address mintFeeRecipient_) external;
    function setProtocolFeeRecipient(address protocolFeeRecipient_) external;
    function setQuestFee(uint16 questFee_) external;

    // Callbacks
    function withdrawCallback(string calldata questId_, address protocolFeeRecipient_, uint protocolPayout_, address mintFeeRecipient_, uint mintPayout) external;
}