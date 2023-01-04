// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Quest} from './Quest.sol';

contract Erc20Quest is Quest {
    using SafeERC20 for IERC20;

    constructor(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalAmount_,
        string memory allowList_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_
    )
        Quest(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalAmount_,
            allowList_,
            rewardAmountInWeiOrTokenId_,
            questId_,
            receiptContractAddress_
        )
    {}

    function start() public override {
        if (IERC20(rewardToken).balanceOf(address(this)) < totalAmount) revert TotalAmountExceedsBalance();
        super.start();
    }

    function claim() public override {
        if (IERC20(rewardToken).balanceOf(address(this)) < rewardAmountInWeiOrTokenId) revert AmountExceedsBalance();
        super.claim();
    }

    function _transferRewards(uint256 amount_) internal override {
        IERC20(rewardToken).safeTransfer(msg.sender, amount_);
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal view override returns (uint256) {
        return redeemableTokenCount_ * rewardAmountInWeiOrTokenId;
    }

    function withdraw() public override onlyOwner {
        super.withdraw();
        IERC20(rewardToken).safeTransfer(msg.sender, IERC20(rewardToken).balanceOf(address(this)));
    }
}
