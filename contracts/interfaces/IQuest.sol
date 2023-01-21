// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// TODO clean this whole thing up
// Allows anyone to claim a token if they exist in a merkle root.
interface IQuest {
    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(address account, uint256 amount);

    error AlreadyClaimed();
    error NoTokensToClaim();
    error EndTimeInPast();
    error StartTimeInPast();
    error ClaimWindowNotStarted();
    error NoWithdrawDuringClaim();
    error TotalAmountExceedsBalance();
    error AmountExceedsBalance();
    error NotStarted();
    error QuestPaused();
    error MustImplementInChild();
}
