// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

// Allows anyone to claim a token if they exist in a merkle root.
interface IQuest {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);
    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    // Returns true if the account has been marked claimed.
    function isClaimed(address account) external view returns (bool);
    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external;

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
}
