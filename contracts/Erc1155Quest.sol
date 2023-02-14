// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {Quest} from './Quest.sol';

/// @title Erc1155Quest
/// @author RabbitHole.gg
/// @dev This contract is used to create quests with a reward token that implements the ERC1155 standard
contract Erc1155Quest is Quest, ERC1155Holder {
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
        address receiptContractAddress_
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
    }

    /// @dev Checks the balance to ensure that it has enough for all of the participants. Only able to be called by owner
    function start() public override {
        if (IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId) < totalParticipants)
            revert TotalAmountExceedsBalance();
        super.start();
    }

    /// @dev Transfers the reward token `rewardAmountInWeiOrTokenId` to the msg.sender
    /// @param amount_ The amount of reward tokens to transfer
    function _transferRewards(uint256 amount_) internal override {
        IERC1155(rewardToken).safeTransferFrom(address(this), msg.sender, rewardAmountInWeiOrTokenId, amount_, '0x00');
    }

    /// @dev Returns the amount of rewards. Since an 1155 is just one token, this returns itself
    /// @param redeemableTokenCount_ The amount of reward tokens that the user is eligible for
    /// @return The amount of reward tokens that the user is eligible for
    function _calculateRewards(uint256 redeemableTokenCount_) internal pure override returns (uint256) {
        return redeemableTokenCount_;
    }

    /// @dev Withdraws the remaining tokens from the contract. Only able to be called by owner
    function withdrawRemainingTokens() external onlyOwner onlyWithdrawAfterEnd {
        IERC1155(rewardToken).safeTransferFrom(
            address(this),
            owner(),
            rewardAmountInWeiOrTokenId,
            IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId),
            '0x00'
        );
    }
}
