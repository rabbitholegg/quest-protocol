// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IQuest1155 {
    // Events
    event Queued(uint256 timestamp);

    event QuestClaimedData(
        address indexed recipient,
        address indexed referrer,
        string extraData
    );

    // Errors
    error EndTimeInPast();
    error EndTimeLessThanOrEqualToStartTime();
    error InsufficientTokenBalance();
    error InsufficientETHBalance();
    error NotStarted();
    error NotEnded();
    error NotQueued();
    error NotQuestFactory();
    error QuestEnded();
    error AlreadyWithdrawn();
    error AddressNotSigned();
    error InvalidClaimFee();
    error AddressAlreadyMinted();
    error OverMaxAllowedToMint();

    // Initializer/Contstructor Function
    function initialize(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 tokenId_,
        uint256 questFee_,
        address protocolFeeRecipient_,
        address claimSignerAddress_
    ) external;

    // Read Functions
    function endTime() external view returns (uint256);
    function hasWithdrawn() external view returns (bool);

    function maxProtocolReward() external view returns (uint256);
    function questFee() external view returns (uint256);
    function queued() external view returns (bool);
    function startTime() external view returns (uint256);
    function tokenId() external view returns (uint256);
    function rewardToken() external view returns (address);

    // Update Functions
    function pause() external;
    function queue() external;
    function singleClaim(address account_) external;
    function unPause() external;
    function withdrawRemainingTokens() external;
    function optimizedClaim(bytes calldata signature_, bytes calldata data_) external payable;
}
