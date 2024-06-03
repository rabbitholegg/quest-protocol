// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Receiver} from "@solady/accounts/Receiver.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {BoostError} from "contracts/references/BoostError.sol";
import {Cloneable} from "contracts/references/Cloneable.sol";

/// @title Boost Budget
/// @notice Abstract contract for a generic Budget within the Boost protocol
/// @dev Budget classes are expected to implement the allocation, reclamation, and disbursement of assets.
/// @dev WARNING: Budgets currently support only ETH, ERC20, and ERC1155 assets. Other asset types may be added in the future.
abstract contract Budget is Ownable, Cloneable, Receiver {
    using SafeTransferLib for address;

    enum AssetType {
        ETH,
        ERC20,
        ERC1155
    }

    /// @notice A struct representing the inputs for an allocation
    /// @param assetType The type of asset to allocate
    /// @param asset The address of the asset to allocate
    /// @param target The address of the payee or payer (from or to, depending on the operation)
    /// @param data The implementation-specific data for the allocation (amount, token ID, etc.)
    struct Transfer {
        AssetType assetType;
        address asset;
        address target;
        bytes data;
    }

    /// @notice The payload for an ETH or ERC20 transfer
    /// @param amount The amount of the asset to transfer
    struct FungiblePayload {
        uint256 amount;
    }

    /// @notice The payload for an ERC1155 transfer
    /// @param tokenId The ID of the token to transfer
    /// @param amount The amount of the token to transfer
    /// @param data Any additional data to forward to the ERC1155 contract
    struct ERC1155Payload {
        uint256 tokenId;
        uint256 amount;
        bytes data;
    }

    /// @notice Emitted when an address's authorization status changes
    event Authorized(address indexed account, bool isAuthorized);

    /// @notice Emitted when assets are distributed from the budget
    event Distributed(address indexed asset, address to, uint256 amount);

    /// @notice Thrown when the allocation is invalid
    error InvalidAllocation(address asset, uint256 amount);

    /// @notice Thrown when there are insufficient funds for an operation
    error InsufficientFunds(address asset, uint256 available, uint256 required);

    /// @notice Thrown when the length of two arrays are not equal
    error LengthMismatch();

    /// @notice Thrown when a transfer fails for an unknown reason
    error TransferFailed(address asset, address to, uint256 amount);

    /// @notice Initialize the budget and set the owner
    /// @dev The owner is set to the contract deployer
    constructor() {
        _initializeOwner(msg.sender);
    }

    /// @notice Allocate assets to the budget
    /// @param data_ The compressed data for the allocation (amount, token address, token ID, etc.)
    /// @return True if the allocation was successful
    function allocate(bytes calldata data_) external payable virtual returns (bool);

    /// @notice Reclaim assets from the budget
    /// @param data_ The compressed data for the reclamation (amount, token address, token ID, etc.)
    /// @return True if the reclamation was successful
    function reclaim(bytes calldata data_) external virtual returns (bool);

    /// @notice Disburse assets from the budget to a single recipient
    /// @param data_ The compressed {Transfer} request
    /// @return True if the disbursement was successful
    function disburse(bytes calldata data_) external virtual returns (bool);

    /// @notice Disburse assets from the budget to multiple recipients
    /// @param data_ The array of compressed {Transfer} requests
    /// @return True if all disbursements were successful
    function disburseBatch(bytes[] calldata data_) external virtual returns (bool);

    /// @notice Get the total amount of assets allocated to the budget, including any that have been distributed
    /// @param asset_ The address of the asset
    /// @return The total amount of assets
    function total(address asset_) external view virtual returns (uint256);

    /// @notice Get the amount of assets available for distribution from the budget
    /// @param asset_ The address of the asset
    /// @return The amount of assets available
    function available(address asset_) external view virtual returns (uint256);

    /// @notice Get the amount of assets that have been distributed from the budget
    /// @param asset_ The address of the asset
    /// @return The amount of assets distributed
    function distributed(address asset_) external view virtual returns (uint256);

    /// @notice Reconcile the budget to ensure the known state matches the actual state
    /// @param data_ The compressed data for the reconciliation (amount, token address, token ID, etc.)
    /// @return The amount of assets reconciled
    function reconcile(bytes calldata data_) external virtual returns (uint256);

    /// @inheritdoc Cloneable
    function supportsInterface(bytes4 interfaceId) public view virtual override(Cloneable) returns (bool) {
        return interfaceId == type(Budget).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Set the authorized status of the given accounts
    /// @param accounts_ The accounts to authorize or deauthorize
    /// @param isAuthorized_ The authorization status for the given accounts
    /// @dev The mechanism for managing authorization is left to the implementing contract
    function setAuthorized(address[] calldata accounts_, bool[] calldata isAuthorized_) external virtual;

    /// @notice Check if the given account is authorized to use the budget
    /// @param account_ The account to check
    /// @return True if the account is authorized
    /// @dev The mechanism for checking authorization is left to the implementing contract
    function isAuthorized(address account_) external view virtual returns (bool);

    /// @inheritdoc Receiver
    receive() external payable virtual override {
        return;
    }

    /// @inheritdoc Receiver
    fallback() external payable virtual override {
        return;
    }
}