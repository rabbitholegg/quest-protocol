// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuard} from 'solmate/src/utils/ReentrancyGuard.sol';
import {Ownable} from 'solady/src/auth/Ownable.sol';
import {SafeTransferLib} from 'solady/src/utils/SafeTransferLib.sol';
import {QuestFactory} from './QuestFactory.sol';

/// @title Quest
/// @author RabbitHole.gg
/// @notice This contract is the Erc1155Quest contract. It is a quest that is redeemable for ERC1155 tokens.
/// @dev This contract will not work with RabbitHoleReceipt
contract Quest1155 is ERC1155Holder, ReentrancyGuard, PausableUpgradeable, Ownable {
    using SafeTransferLib for address;

    QuestFactory public questFactoryContract;
    bool public queued;
    address public protocolFeeRecipient;
    address public rewardToken;
    uint public endTime;
    uint public startTime;
    uint public totalParticipants;
    uint public tokenId;
    uint public redeemedTokens;
    uint16 public questFee;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    error EndTimeInPast();
    error EndTimeLessThanOrEqualToStartTime();
    error TotalAmountExceedsBalance();
    error NoWithdrawDuringClaim();
    error NotStarted();
    error ClaimWindowNotStarted();
    error NotQuestFactory();

    event ClaimedSingle(address indexed account, address rewardAddress, uint amount);
    event Queued(uint timestamp);

    function initialize(
        address rewardTokenAddress_,
        uint endTime_,
        uint startTime_,
        uint totalParticipants_,
        uint tokenId_,
        uint16 questFee_,
        address protocolFeeRecipient_
    ) external initializer {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (endTime_ <= startTime_) revert EndTimeLessThanOrEqualToStartTime();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = rewardTokenAddress_;
        totalParticipants = totalParticipants_;
        tokenId = tokenId_;
        questFactoryContract = QuestFactory(payable(msg.sender));
        questFee = questFee_;
        protocolFeeRecipient = protocolFeeRecipient_;
        _initializeOwner(msg.sender);
        __Pausable_init();
    }

    /// @notice Queues the quest by marking it ready to start at the contract level. Marking a quest as queued does not mean that it is live. It also requires that the start time has passed
    /// @dev Requires that the balance of the rewards in the contract is greater than or equal to the maximum amount of rewards that can be claimed by all users and the protocol
    function queue() public virtual onlyOwner {
        if (IERC1155(rewardToken).balanceOf(address(this), tokenId) < this.maxProtocolReward())
            revert TotalAmountExceedsBalance();
        queued = true;
        emit Queued(block.timestamp);
    }

    /// @notice Pauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function pause() external onlyOwner onlyStarted {
        _pause();
    }

    /// @notice Unpauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function unPause() external onlyOwner onlyStarted {
        _unpause();
    }

    /// @notice Prevents reward withdrawal until the Quest has ended
    modifier onlyWithdrawAfterEnd() {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        _;
    }

    /// @notice Checks if the Quest has started at the function level
    modifier onlyStarted() {
        if (!queued) revert NotStarted();
        _;
    }

    /// @notice Checks if quest has started both at the function level and at the start time
    modifier onlyQuestActive() {
        if (!queued) revert NotStarted();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        _;
    }

    modifier onlyProtocolFeeRecipientOrOwner() {
        require(msg.sender == protocolFeeRecipient || msg.sender == owner(), 'Not protocol fee recipient or owner');
        _;
    }

    modifier onlyQuestFactory() {
        if (msg.sender != address(questFactoryContract)) revert NotQuestFactory();
        _;
    }

    /// @dev transfers rewards to the account, can only be called once per account per quest and only by the quest factory
    /// @param account_ The account to transfer rewards to
    function singleClaim(address account_) external virtual nonReentrant onlyQuestActive whenNotPaused onlyQuestFactory {
        redeemedTokens = redeemedTokens + 1;
        _transferRewards(account_, 1);
        protocolFeeRecipient.safeTransferETH(questFee);
        emit ClaimedSingle(account_, rewardToken, 1);
    }

    /// @notice Function that gets the maximum amount of rewards that can be claimed by the protocol or the quest deployer
    /// @return The maximum amount of rewards that can be claimed by the protocol or the quest deployer
    function maxProtocolReward() external view returns (uint) {
        return (totalParticipants * questFee);
    }

    /// @notice Internal function that transfers rewards from this contract
    /// @param to_ The address to send the rewards to
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(address to_, uint amount_) internal {
        IERC1155(rewardToken).safeTransferFrom(address(this), to_, tokenId, amount_, '0x00');
    }

    /// @dev Function that transfers all 1155 tokens in the contract to the owner
    /// @notice This function can only be called after the quest end time.
    function withdrawRemainingTokens() external onlyWithdrawAfterEnd {
        _transferRewards(owner(), IERC1155(rewardToken).balanceOf(address(this), tokenId));
    }
}
