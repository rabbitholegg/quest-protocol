// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract Errors {
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error AmountExceedsBalance();
    error ClaimWindowNotStarted();
    error EndTimeInPast();
    error EndTimeLessThanOrEqualToStartTime();
    error InvalidRefundToken();
    error MustImplementInChild();
    error NotQuestFactory();
    error NoWithdrawDuringClaim();
    error NotStarted();
    error TotalAmountExceedsBalance();
    error AuthOwnerRecipient();
    error Unauthorized();
    error EnforcedPause();

    // Quest1155
    error InsufficientTokenBalance();
    error InsufficientETHBalance();
}
