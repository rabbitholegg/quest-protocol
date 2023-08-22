// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {EIP712} from "solady/src/utils/EIP712.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {IProtocolRewards} from "./interfaces/IProtocolRewards.sol";

/// @title ProtocolRewards
/// @notice Manager of deposits & withdrawals for protocol rewards
contract ProtocolRewards is IProtocolRewards, EIP712, Ownable {
    /// @notice The EIP-712 typehash for gasless withdraws
    bytes32 public constant WITHDRAW_TYPEHASH =
        keccak256("Withdraw(address from,address to,uint256 amount,uint256 nonce,uint256 deadline)");

    /// @notice An account's balance
    mapping(address => uint256) public balanceOf;

    /// @notice An account's nonce for gasless withdraws
    mapping(address => uint256) public nonces;

    /// @notice Total Balance across all accounts
    uint256 public totalBalance;

    constructor() payable EIP712() {
        _initializeOwner(msg.sender);
    }

    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory name, string memory version)
    {
        name = "ProtocolRewards";
        version = "1";
    }

    /// @notice The total amount of ETH held in the contract
    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice The total excess amount of ETH held in the contract
    function excessSupply() external view returns (uint256) {
        return address(this).balance - totalBalance;
    }

    /// @notice Generic function to deposit ETH for a recipient, with an optional comment
    /// @param to Address to deposit to
    /// @param to Reason system reason for deposit (used for indexing)
    /// @param comment Optional comment as reason for deposit
    function deposit(address to, bytes4 reason, string calldata comment) external payable {
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        _increaseBalance(to, msg.value);

        emit Deposit(msg.sender, to, reason, msg.value, comment);
    }

    /// @notice Allow admin to increase balance of an address only up the amount of excess ETH in the contract
    /// @param to The address to increase the balance of
    /// @param amount The amount to increase the balance by
    function increaseBalance(address to, uint256 amount) external onlyOwner {
        if (amount > this.excessSupply()) {
            revert INVALID_AMOUNT();
        }
        _increaseBalance(to, amount);

        //todo emit event here, same basically as deposit
    }

    /// @notice Increase the balance of addresses in amounts in a batch function
    function increaseBalanceBatch(address[] calldata to, uint256[] calldata amounts) external onlyOwner {
        uint256 numRecipients = to.length;

        if (numRecipients != amounts.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        // do we do this here, or we can check inside the next loop also
        uint256 expectedTotalValue;
        for (uint256 i; i < numRecipients;) {
            expectedTotalValue += amounts[i];

            unchecked {
                ++i;
            }
        }
        if (expectedTotalValue > this.excessSupply()) {
            revert INVALID_AMOUNT();
        }

        address currentRecipient;
        uint256 currentAmount;

        for (uint256 i; i < numRecipients;) {
            currentRecipient = to[i];
            currentAmount = amounts[i];

            if (currentRecipient == address(0)) {
                revert ADDRESS_ZERO();
            }

            // this check is redundant because of the check above, unless we remove it?
            if (currentAmount > this.excessSupply()) {
                revert INVALID_AMOUNT();
            }
            _increaseBalance(currentRecipient, currentAmount);

            //todo emit event here, same basically as deposit

            unchecked {
                ++i;
            }
        }
    }

    function _increaseBalance(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalBalance += amount;
    }

    function _decreaseBalance(address to, uint256 amount) internal {
        balanceOf[to] -= amount;
        totalBalance -= amount;
    }

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
    ) external payable {
        uint256 numRecipients = recipients.length;

        if (numRecipients != amounts.length || numRecipients != reasons.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        uint256 expectedTotalValue;

        for (uint256 i; i < numRecipients;) {
            expectedTotalValue += amounts[i];

            unchecked {
                ++i;
            }
        }

        if (msg.value != expectedTotalValue) {
            revert INVALID_DEPOSIT();
        }

        address currentRecipient;
        uint256 currentAmount;

        for (uint256 i; i < numRecipients;) {
            currentRecipient = recipients[i];
            currentAmount = amounts[i];

            if (currentRecipient == address(0)) {
                revert ADDRESS_ZERO();
            }

            _increaseBalance(currentRecipient, currentAmount);

            emit Deposit(msg.sender, currentRecipient, reasons[i], currentAmount, comment);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Withdraw protocol rewards
    /// @param to Withdraws from msg.sender to this address
    /// @param amount Amount to withdraw (0 for total balance)
    function withdraw(address to, uint256 amount) external {
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        address owner = msg.sender;

        if (amount > balanceOf[owner]) {
            revert INVALID_WITHDRAW();
        }

        if (amount == 0) {
            amount = balanceOf[owner];
        }

        _decreaseBalance(owner, amount);

        emit Withdraw(owner, to, amount);

        (bool success,) = to.call{value: amount}("");

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /// @notice Withdraw rewards on behalf of an address
    /// @param to The address to withdraw for
    /// @param amount The amount to withdraw (0 for total balance)
    function withdrawFor(address to, uint256 amount) external {
        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        if (amount > balanceOf[to]) {
            revert INVALID_WITHDRAW();
        }

        if (amount == 0) {
            amount = balanceOf[to];
        }

        balanceOf[to] -= amount;

        emit Withdraw(to, to, amount);

        (bool success,) = to.call{value: amount}("");

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /// @notice Execute a withdraw of protocol rewards via signature
    /// @param from Withdraw from this address
    /// @param to Withdraw to this address
    /// @param amount Amount to withdraw (0 for total balance)
    /// @param deadline Deadline for the signature to be valid
    /// @param v V component of signature
    /// @param r R component of signature
    /// @param s S component of signature
    function withdrawWithSig(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > deadline) {
            revert SIGNATURE_DEADLINE_EXPIRED();
        }

        bytes32 withdrawHash;

        unchecked {
            withdrawHash = keccak256(abi.encode(WITHDRAW_TYPEHASH, from, to, amount, nonces[from]++, deadline));
        }

        bytes32 digest = _hashTypedData(withdrawHash);

        address recoveredAddress = ecrecover(digest, v, r, s);

        if (recoveredAddress == address(0) || recoveredAddress != from) {
            revert INVALID_SIGNATURE();
        }

        if (to == address(0)) {
            revert ADDRESS_ZERO();
        }

        if (amount > balanceOf[from]) {
            revert INVALID_WITHDRAW();
        }

        if (amount == 0) {
            amount = balanceOf[from];
        }

        _decreaseBalance(from, amount);

        emit Withdraw(from, to, amount);

        (bool success,) = to.call{value: amount}("");

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}
