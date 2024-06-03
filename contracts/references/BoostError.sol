// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

/// @title BoostError
/// @notice Standardized errors for the Boost protocol
/// @dev Some of these errors are introduced by third-party libraries, rather than Boost contracts directly, and are copied here for clarity and ease of testing.
library BoostError {
    /// @notice Thrown when a claim attempt fails
    error ClaimFailed(address caller, bytes data);

    /// @notice Thrown when there are insufficient funds for an operation
    error InsufficientFunds(address asset, uint256 available, uint256 required);

    /// @notice Thrown when a non-conforming instance for a given type is encountered
    error InvalidInstance(bytes4 expectedInterface, address instance);

    /// @notice Thrown when an invalid initialization is attempted
    error InvalidInitialization();

    /// @notice Thrown when the length of two arrays are not equal
    error LengthMismatch();

    /// @notice Thrown when a method is not implemented
    error NotImplemented();

    /// @notice Thrown when a previously used signature is replayed
    error Replayed(address signer, bytes32 hash, bytes signature);

    /// @notice Thrown when a transfer fails for an unknown reason
    error TransferFailed(address asset, address to, uint256 amount);

    /// @notice Thrown when the requested action is unauthorized
    error Unauthorized();
}