// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import {Ownable} from 'solady/src/auth/Ownable.sol';
import {SafeTransferLib} from 'solady/src/utils/SafeTransferLib.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import {QuestFactory} from './QuestFactory.sol';
import {IQuest} from './interfaces/IQuest.sol';

/// @title Quest
/// @author RabbitHole.gg
/// @notice This contract is the Erc20Quest contract. It is a quest that is redeemable for ERC20 tokens
contract Quest is ReentrancyGuardUpgradeable, PausableUpgradeable, Ownable, IQuest {
    using SafeTransferLib for address;
    RabbitHoleReceipt public rabbitHoleReceiptContract;    // Deprecated - do not use
    QuestFactory public questFactoryContract;
    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalParticipants;
    uint256 public rewardAmountInWei;
    bool public queued;
    string public questId;
    uint256 public redeemedTokens;
    uint16 public questFee;
    bool public hasWithdrawn;
    address public protocolFeeRecipient;
    mapping(uint256 => bool) private claimedList;
    string public jsonSpecCID;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountInWei_,
        string memory questId_,
        uint16 questFee_,
        address protocolFeeRecipient_
    ) external initializer {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (endTime_ <= startTime_) revert EndTimeLessThanOrEqualToStartTime();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = rewardTokenAddress_;
        totalParticipants = totalParticipants_;
        rewardAmountInWei = rewardAmountInWei_;
        questId = questId_;
        questFactoryContract = QuestFactory(payable(msg.sender));
        questFee = questFee_;
        hasWithdrawn = false;
        protocolFeeRecipient = protocolFeeRecipient_;
        _initializeOwner(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /// @dev The amount of tokens the quest needs to pay all redeemers plus the protocol fee
    function totalTransferAmount() external view returns (uint256) {
        return this.maxTotalRewards() + this.maxProtocolReward();
    }

    /// @notice Queues the quest by marking it ready to start at the contract level. Marking a quest as queued does not mean that it is live. It also requires that the start time has passed
    /// @dev Requires that the balance of the rewards in the contract is greater than or equal to the maximum amount of rewards that can be claimed by all users and the protocol
    function queue() public virtual onlyOwner {
        if (rewardToken.balanceOf(address(this)) < this.totalTransferAmount())
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

    /// @notice Marks token ids as claimed
    /// @param tokenIds_ The token ids to mark as claimed
    function _setClaimed(uint256[] memory tokenIds_) private {
        for (uint i = 0; i < tokenIds_.length; ) {
            claimedList[tokenIds_[i]] = true;
            unchecked {
                i++;
            }
        }
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
        uint256 totalRedeemableRewards = rewardAmountInWei;
        _transferRewards(account_, totalRedeemableRewards);
        redeemedTokens = redeemedTokens + 1;
        emit ClaimedSingle(account_, rewardToken, totalRedeemableRewards);
    }


    /// @dev Function that gets the maximum amount of rewards that can be claimed by all users. It does not include the protocol fee
    /// @return The maximum amount of rewards that can be claimed by all users
    function maxTotalRewards() external view returns (uint256) {
        return totalParticipants * rewardAmountInWei;
    }

    /// @notice Function that gets the maximum amount of rewards that can be claimed by the protocol or the quest deployer
    /// @dev The 10_000 comes from Basis Points: https://www.investopedia.com/terms/b/basispoint.asp
    /// @return The maximum amount of rewards that can be claimed by the protocol or the quest deployer
    function maxProtocolReward() external view returns (uint256) {
        return (this.maxTotalRewards() * questFee) / 10_000;
    }

    /// @notice Internal function that transfers the rewards to the msg.sender
    /// @param sender_ The address to send the rewards to
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(address sender_, uint256 amount_) internal {
        rewardToken.safeTransfer(sender_, amount_);
    }


    /// @notice Function that allows either the protocol fee recipient or the owner to withdraw the remaining tokens in the contract
    /// @dev Can only be called after the quest has ended - pays protocol fee and returns remaining tokens to owner
    function withdrawRemainingTokens() external onlyProtocolFeeRecipientOrOwner onlyWithdrawAfterEnd {
        require(!hasWithdrawn, 'Already withdrawn');

        rewardToken.safeTransfer(protocolFeeRecipient, this.protocolFee());

        rewardToken.safeTransfer(owner(), rewardToken.balanceOf(address(this)));

        hasWithdrawn = true;

    }

    /// @notice Function that calculates the protocol fee
    function protocolFee() external view returns (uint256) {
        return (this.receiptRedeemers() * rewardAmountInWei * questFee) / 10_000;
    }

    /// @notice This no longer indicates a number of receipts minted but gives an accurate count of total claims
    /// @return total number of claims submitted
    function receiptRedeemers() public view returns (uint256) {
        return questFactoryContract.getNumberMinted(questId);
    }

    /// @notice Checks if a Receipt token id has been used to claim a reward
    /// @param tokenId_ The token id to check
    function isClaimed(uint256 tokenId_) external view returns (bool) {
        return claimedList[tokenId_] == true;
    }

    /// @dev Returns the reward amount
    function getRewardAmount() external view returns (uint256) {
        return rewardAmountInWei;
    }

    /// @dev Returns the reward token address
    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    /// @dev transfer all coins and tokens that is not the rewardToken to the contract owner.
    /// @param erc20Address_ The address of the ERC20 token to refund
    function refund(address erc20Address_) external onlyOwner {
        require(erc20Address_ != rewardToken, 'Cannot refund reward token');

        uint balance = address(this).balance;
        if (balance > 0) payable(msg.sender).transfer(balance);

        uint erc20Balance = erc20Address_.balanceOf(address(this));
        if (erc20Balance > 0) erc20Address_.safeTransfer(msg.sender, erc20Balance);
    }
}
