// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuest {
    // Remove
    event Claimed(address indexed account, address rewardAddress, uint256 amount);
    event ClaimedSingle(address indexed account, address rewardAddress, uint256 amount);
    event Queued(uint timestamp);
    event JsonSpecCIDSet(string cid);

    error AlreadyClaimed();
    error AmountExceedsBalance();
    error ClaimWindowNotStarted();
    error EndTimeInPast();
    error EndTimeLessThanOrEqualToStartTime();
    error MustImplementInChild();
    error NotQuestFactory();
    // Remove
    error NoTokensToClaim();
    error NoWithdrawDuringClaim();
    error NotStarted();
    error TotalAmountExceedsBalance();

    function isClaimed(uint256 tokenId_) external view returns (bool);
    function getRewardAmount() external view returns (uint256);
    function getRewardToken() external view returns (address);
    function queued() external view returns (bool);
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function singleClaim(address account) external;
    function rewardToken() external view returns (address);
    function rewardAmountInWei() external view returns (uint256);
}
