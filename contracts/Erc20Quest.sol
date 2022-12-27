// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20Upgradeable, SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {Quest} from './Quest.sol';

contract Erc20Quest is Quest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function start() public override {
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < totalAmount) revert TotalAmountExceedsBalance();
        super.start();
    }

    function claim(uint timestamp_, bytes32 hash_, bytes memory signature_) public override {
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < rewardAmountInWeiOrTokenId) revert AmountExceedsBalance();
        super.claim(timestamp_, hash_, signature_);
    }

    function _transferRewards(uint256 amount_) internal override {
        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, amount_);
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal view override returns (uint256) {
        return redeemableTokenCount_ * rewardAmountInWeiOrTokenId;
    }

    function withdraw() public override onlyOwner {
        super.withdraw();
        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, IERC20Upgradeable(rewardToken).balanceOf(address(this)));
    }
}
