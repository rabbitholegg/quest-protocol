// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;
// TODO clean this whole thing up
// Allows anyone to claim a token if they exist in a merkle root.
interface IQuest {
    // Returns the address of the token distributed by this contract.
    function rewardToken() external view returns (address);
    // Returns true if the account has been marked claimed.
    function isClaimed(address account) external view returns (bool);

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(address account, uint256 amount);

    error AlreadyClaimed();
    error InvalidProof();
    error EndTimeInPast();
    error StartTimeInPast();
    error ClaimWindowFinished();
    error ClaimWindowNotStarted();
    error NoWithdrawDuringClaim();
    error TotalAmountExceedsBalance();
    error AmountExceedsBalance();
    error NotStarted();
    error QuestPaused();
}
