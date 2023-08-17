// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuest1155 {
    // Events
    event ClaimedSingle(address indexed account, address rewardAddress, uint amount);
    event Queued(uint timestamp);

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

    // Initializer/Contstructor Function
    function initialize(
        address rewardTokenAddress_,
        uint endTime_,
        uint startTime_,
        uint totalParticipants_,
        uint tokenId_,
        uint questFee_,
        address protocolFeeRecipient_
    ) external;

    // Read Functions
    function endTime() external view returns (uint256);
    function hasWithdrawn() external view returns (bool);

    function maxProtocolReward() external view returns (uint);
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
}