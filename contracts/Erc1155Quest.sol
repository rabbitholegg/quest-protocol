// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {Quest} from './Quest.sol';

contract Erc1155Quest is Quest, ERC1155Holder {
    function start() public override {
        if (IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId) < totalAmount) revert TotalAmountExceedsBalance();
        super.start();
    }

    function claim(bytes32 hash, bytes memory signature) public override {
        if (IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId) < totalAmount) revert AmountExceedsBalance();
        super.claim(hash, signature);
    }

    function _transferRewards(uint256 amount) internal override {
        IERC1155(rewardToken).safeTransferFrom(address(this), msg.sender, rewardAmountInWeiOrTokenId, amount, '0x00');
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal pure override returns (uint256) {
        return redeemableTokenCount_;
    }

    function withdraw() public override onlyOwner {
        super.withdraw();
        IERC1155(rewardToken).safeTransferFrom(
            address(this),
            msg.sender,
            rewardAmountInWeiOrTokenId,
            IERC1155(rewardToken).balanceOf(address(this), rewardAmountInWeiOrTokenId),
            '0x00'
        );
    }
}