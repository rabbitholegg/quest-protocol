// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title IProtocolRewards
/// @notice The interface for deposits & withdrawals for Protocol Rewards
interface IProtocolRewards {
    /// @notice Deposit Event
    /// @param from From user
    /// @param to To user (within contract)
    /// @param reason Optional bytes4 reason for indexing
    /// @param amount Amount of deposit
    /// @param comment Optional user comment
    event Deposit(address indexed from, address indexed to, bytes4 indexed reason, uint256 amount, string comment);

    event IncreaseBalance(address indexed to, uint256 amount);

    /// @notice Withdraw Event
    /// @param from From user
    /// @param to To user (within contract)
    /// @param amount Amount of deposit
    event Withdraw(address indexed from, address indexed to, uint256 amount);

    event TransferExcessSupply(address indexed from, address indexed to, uint256 amount);

    /// @notice Cannot send to address zero
    error ADDRESS_ZERO();

    /// @notice Function argument array length mismatch
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Invalid deposit
    error INVALID_DEPOSIT();

    /// @notice Invalid withdraw
    error INVALID_WITHDRAW();

    error INVALID_AMOUNT();

    /// @notice Generic function to deposit ETH for a recipient, with an optional comment
    /// @param to Address to deposit to
    /// @param to Reason system reason for deposit (used for indexing)
    /// @param comment Optional comment as reason for deposit
    function deposit(address to, bytes4 why, string calldata comment) external payable;

    /// @notice Generic function to deposit ETH for multiple recipients, with an optional comment
    /// @param recipients recipients to send the amount to, array aligns with amounts
    /// @param amounts amounts to send to each recipient, array aligns with recipients
    /// @param reasons optional bytes4 hash for indexing
    /// @param comment Optional comment to include with mint
    function depositBatch(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes4[] calldata reasons,
        string calldata comment
    ) external payable;

    /// @notice Withdraw protocol rewards
    /// @param to Withdraws from msg.sender to this address
    /// @param amount amount to withdraw
    function withdraw(address to, uint256 amount) external;

    function excessSupply() external view returns (uint256);

    /// @param to Increase the balance of an address
    /// @param amount Amount to increase by
    function increaseBalance(address to, uint256 amount) external;

    /// @param to array of addresses to increase the balance of
    /// @param amounts Amounts to increase by
    function increaseBalanceBatch(address[] calldata to, uint256[] calldata amounts) external;
}
