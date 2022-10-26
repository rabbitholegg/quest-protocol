// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import {MerkleDistributor} from "./MerkleDistributor.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error EndTimeInPast();
error ClaimWindowFinished();
error NoWithdrawDuringClaim();

contract MerkleDistributorRH is MerkleDistributor {
  using SafeERC20 for IERC20;

  uint256 public immutable endTime;

  constructor(address token_, uint256 endTime_) MerkleDistributor (token_) {
    if (endTime_ <= block.timestamp) revert EndTimeInPast();
    endTime = endTime_;
  }

  function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public override {
    if (block.timestamp > endTime) revert ClaimWindowFinished();
    super.claim(index, account, amount, merkleProof);
  }

  function withdraw() external onlyOwner {
    if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
    IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
  }
}
