// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPoints
/// @notice Interface for the Points contract to track soulbound points on-chain.
interface IPoints {
  
    /// @notice Initialize the Points contract with a name, symbol, and initial minter.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param minter_ The initial holder of the minter role.
    function initialize(string calldata name_, string calldata symbol_, address minter_) external;

    /// @notice Issue a specified amount of points and assign them to a specified address.
    /// @param to The address to assign the points to.
    /// @param amount The amount of points to issue.
    function issue(address to, uint256 amount) external;

    /// @notice Get the name of the token.
    /// @return The name of the token.
    function name() external view returns (string memory);

    /// @notice Get the symbol of the token.
    /// @return The symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Check if an address has the issuer role
    /// @param user The address to check
    /// @return bool if the address has the issuer role, false otherwise
    function hasIssuerRole(address user) external view returns (bool);

    /// @notice Grant the issuer role to an account
    /// @param account The account to grant the issuer role to
    function grantIssuerRole(address account) external;
}