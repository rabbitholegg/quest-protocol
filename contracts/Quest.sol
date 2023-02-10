// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {IQuest} from './interfaces/IQuest.sol';
import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

/// @title Quest
/// @author RabbitHole.gg
/// @notice This contract is the base contract for all Quests. The Erc20Quest and Erc1155Quest contracts inherit from this contract.
contract Quest is OwnableUpgradeable, IQuest {
    using SafeERC20 for IERC20;

    RabbitHoleReceipt public rabbitHoleReceiptContract;
    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalParticipants;
    uint256 public rewardAmountInWeiOrTokenId;
    bool public hasStarted;
    bool public isPaused;
    string public questId;
    uint256 public redeemedTokens;

    mapping(uint256 => bool) private claimedList;

    function questInit(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_
    ) public onlyInitializing {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (startTime_ <= block.timestamp) revert StartTimeInPast();
        if (endTime_ <= startTime_) revert EndTimeLessThanOrEqualToStartTime();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = rewardTokenAddress_;
        totalParticipants = totalParticipants_;
        rewardAmountInWeiOrTokenId = rewardAmountInWeiOrTokenId_;
        questId = questId_;
        rabbitHoleReceiptContract = RabbitHoleReceipt(receiptContractAddress_);
        __Ownable_init();
    }

    /// @notice Starts the Quest
    /// @dev Only the owner of the Quest can call this function
    function start() public virtual onlyOwner {
        isPaused = false;
        hasStarted = true;
    }

    /// @notice Pauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function pause() external onlyOwner onlyStarted {
        isPaused = true;
    }

    /// @notice Unpauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function unPause() external onlyOwner onlyStarted {
        isPaused = false;
    }

    /// @notice Marks token ids as claimed
    /// @param tokenIds_ The token ids to mark as claimed
    function _setClaimed(uint256[] memory tokenIds_) private {
        for (uint i = 0; i < tokenIds_.length;) {
            claimedList[tokenIds_[i]] = true;
        unchecked{i++;}
        }
    }

    /// @notice Prevents reward withdrawal until the Quest has ended
    modifier onlyWithdrawAfterEnd() {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        _;
    }

    /// @notice Checks if the Quest has started at the function level
    modifier onlyStarted() {
        if (!hasStarted) revert NotStarted();
        _;
    }

    /// @notice Checks if quest has started both at the function level and at the start time
    modifier onlyQuestActive() {
        if (!hasStarted) revert NotStarted();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        _;
    }

    /// @notice Allows user to claim the rewards entitled to them
    /// @dev User can claim based on the (unclaimed) number of tokens they own of the Quest
    function claim() external virtual onlyQuestActive {
        if (isPaused) revert QuestPaused();

        uint[] memory tokens = rabbitHoleReceiptContract.getOwnedTokenIdsOfQuest(questId, msg.sender);

        if (tokens.length == 0) revert NoTokensToClaim();

        uint256 redeemableTokenCount = 0;
        for (uint i = 0; i < tokens.length;) {
            if (!this.isClaimed(tokens[i])) {
            unchecked{redeemableTokenCount++;}
            }
        unchecked{i++;}
        }

        if (redeemableTokenCount == 0) revert AlreadyClaimed();

        uint256 totalRedeemableRewards = _calculateRewards(redeemableTokenCount);
        _setClaimed(tokens);
        _transferRewards(totalRedeemableRewards);
        redeemedTokens = redeemedTokens + redeemableTokenCount;

        emit Claimed(msg.sender, rewardToken, totalRedeemableRewards);
    }

    /// @notice Calculate the amount of rewards
    /// @dev This function must be implemented in the child contracts
    function _calculateRewards(uint256 redeemableTokenCount_) internal virtual returns (uint256) {
        revert MustImplementInChild();
    }

    /// @notice Transfer the rewards to the user
    /// @dev This function must be implemented in the child contracts
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(uint256 amount_) internal virtual {
        revert MustImplementInChild();
    }

    /// @notice Checks if a Receipt token id has been used to claim a reward
    /// @param tokenId_ The token id to check
    function isClaimed(uint256 tokenId_) external view returns (bool) {
        return claimedList[tokenId_] == true;
    }

    /// @dev Returns the reward amount
    function getRewardAmount() external view returns (uint256) {
        return rewardAmountInWeiOrTokenId;
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

        uint erc20Balance = IERC20(erc20Address_).balanceOf(address(this));
        if (erc20Balance > 0) IERC20(rewardToken).safeTransfer(msg.sender, erc20Balance);
    }
}
