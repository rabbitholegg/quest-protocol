// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Quest} from './Quest.sol';
import {QuestFactory} from './QuestFactory.sol';

/// @title Erc20Quest
/// @author RabbitHole.gg
/// @notice This contract is used to create a quest that rewards ERC20 tokens.
contract Erc20Quest is Quest {
    using SafeERC20 for IERC20;
    uint16 public questFee;
    bool public hasWithdrawn;
    address public protocolFeeRecipient;
    QuestFactory public questFactoryContract;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_,
        uint16 questFee_,
        address protocolFeeRecipient_
    ) external initializer {
        super.questInit(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmountInWeiOrTokenId_,
            questId_,
            receiptContractAddress_
        );
        questFee = questFee_;
        hasWithdrawn = false;
        protocolFeeRecipient = protocolFeeRecipient_;
        questFactoryContract = QuestFactory(msg.sender);
    }

    modifier onlyProtocolFeeRecipientOrOwner() {
        require(msg.sender == protocolFeeRecipient || msg.sender == owner(), 'Not protocol fee recipient or owner');
        _;
    }

    /// @dev Function that gets the maximum amount of rewards that can be claimed by all users. It does not include the protocol fee
    /// @return The maximum amount of rewards that can be claimed by all users
    function maxTotalRewards() external view returns (uint256) {
        return totalParticipants * rewardAmountInWeiOrTokenId;
    }

    /// @notice Function that gets the maximum amount of rewards that can be claimed by the protocol or the quest deployer
    /// @dev The 10_000 comes from Basis Points: https://www.investopedia.com/terms/b/basispoint.asp
    /// @return The maximum amount of rewards that can be claimed by the protocol or the quest deployer
    function maxProtocolReward() external view returns (uint256) {
        return (this.maxTotalRewards() * questFee) / 10_000;
    }

    /// @notice Starts the quest by marking it ready to start at the contract level. Marking a quest ready to start does not mean that it is live. It also requires that the start time has passed
    /// @dev Requires that the balance of the rewards in the contract is greater than or equal to the maximum amount of rewards that can be claimed by all users and the protocol
    function start() public override {
        if (IERC20(rewardToken).balanceOf(address(this)) < this.maxTotalRewards() + this.maxProtocolReward())
            revert TotalAmountExceedsBalance();
        super.start();
    }

    /// @notice Internal function that transfers the rewards to the msg.sender
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(uint256 amount_) internal override {
        IERC20(rewardToken).safeTransfer(msg.sender, amount_);
    }

    /// @notice Internal function that calculates the reward amount
    /// @dev It is possible for users to have multiple receipts (if they buy others on secondary markets)
    /// @param redeemableTokenCount_ The amount of tokens that can be redeemed
    /// @return The total amount of rewards that can be claimed by a user
    function _calculateRewards(uint256 redeemableTokenCount_) internal view override returns (uint256) {
        return redeemableTokenCount_ * rewardAmountInWeiOrTokenId;
    }

    /// @notice Function that allows either the protocol fee recipient or the owner to withdraw the remaining tokens in the contract
    /// @dev Every receipt minted should still be able to claim rewards (and cannot be withdrawn). This function can only be called after the quest end time
    function withdrawRemainingTokens() external onlyProtocolFeeRecipientOrOwner onlyWithdrawAfterEnd {
        require(!hasWithdrawn, 'Already withdrawn');

        uint unclaimedTokens = (this.receiptRedeemers() - redeemedTokens) * rewardAmountInWeiOrTokenId;
        uint256 nonClaimableTokens = IERC20(rewardToken).balanceOf(address(this)) - this.protocolFee() - unclaimedTokens;
        hasWithdrawn = true;

        IERC20(rewardToken).safeTransfer(owner(), nonClaimableTokens);
        IERC20(rewardToken).safeTransfer(protocolFeeRecipient, this.protocolFee());
    }

    /// @notice Call the QuestFactory contract to get the amount of receipts that have been minted
    /// @return The amount of receipts that have been minted for the given quest
    function receiptRedeemers() external view returns (uint256) {
        return questFactoryContract.getNumberMinted(questId);
    }

    /// @notice Function that calculates the protocol fee
    function protocolFee() external view returns (uint256) {
        return (this.receiptRedeemers() * rewardAmountInWeiOrTokenId * questFee) / 10_000;
    }
}
