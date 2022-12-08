// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Quest} from "./Quest.sol"

contract Erc20Quest is Quest {
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) public virtual {
        if (hasStarted == false) revert NotStarted();
        if (isPaused == true) revert QuestPaused();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        if (isClaimed(account)) revert AlreadyClaimed();
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < amount) revert AmountExceedsBalance();

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(account, amount));
        if (!MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

        // Mark it claimed and send the rewardToken.
        IERC20Upgradeable(rewardToken).safeTransfer(account, rewardAmountInWei);
        _setClaimed(account);

        emit Claimed(account, amount);
    }

    function isClaimed(address account) public view returns (bool) {
        return claimedList[account] && claimedList[account] == true;
    }

    function withdraw() public onlyOwner {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, IERC20Upgradeable(rewardToken).balanceOf(address(this)));
    }
}
