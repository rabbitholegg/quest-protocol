// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

// TODO clean this whole thing up
// Allows anyone to claim a token if they exist in a merkle root.
interface IQuest {
    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(address account, address rewardAddress, uint256 amount);

    error AlreadyClaimed();
    error NoTokensToClaim();
    error EndTimeInPast();
    error StartTimeInPast();
    error EndTimeLessThanOrEqualToStartTime();
    error ClaimWindowNotStarted();
    error NoWithdrawDuringClaim();
    error TotalAmountExceedsBalance();
    error AmountExceedsBalance();
    error NotStarted();
    error QuestPaused();
    error MustImplementInChild();

    function isClaimed(uint256 tokenId_) external view returns (bool);

    function getRewardAmount() external view returns (uint256);

    function getRewardToken() external view returns (address);
}
