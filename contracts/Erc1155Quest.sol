// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {Quest} from './Quest.sol';

contract Erc1155Quest is Quest, ERC1155Holder {
    constructor(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalAmount_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_
    )
        Quest(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalAmount_,
            rewardAmountInWeiOrTokenId_,
            questId_,
            receiptContractAddress_
        )
    {}

    function start() public override {
        if (IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId) < totalAmount)
            revert TotalAmountExceedsBalance();
        super.start();
    }

    function claim() public override {
        if (IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId) < totalAmount)
            revert AmountExceedsBalance();
        super.claim();
    }

    function _transferRewards(uint256 amount_) internal override {
        IERC1155(rewardToken).safeTransferFrom(address(this), msg.sender, rewardAmountInWeiOrTokenId, amount_, '0x00');
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal pure override returns (uint256) {
        return redeemableTokenCount_;
    }

    function withdrawRemainingTokens() public override onlyOwner {
        super.withdrawRemainingTokens();
        IERC1155(rewardToken).safeTransferFrom(
            address(this),
            msg.sender,
            rewardAmountInWeiOrTokenId,
            IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId),
            '0x00'
        );
    }
}
