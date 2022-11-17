// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IMerkleDistributor} from "./interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor, Ownable, Initializable {
  using SafeERC20 for IERC20;

  address public immutable token;
  uint256 public immutable endTime;
  uint256 public immutable startTime;
  uint256 public immutable totalAmount;
  bytes32 public merkleRoot;
  bool public hasStarted;

  // This is a packed array of booleans.
  mapping(address => bool) private claimedList;

  constructor(address token_, uint256 endTime_, uint256 startTime_, uint256 totalAmount_) {
    if (endTime_ <= block.timestamp) revert EndTimeInPast();
    if (startTime_ <= block.timestamp) revert StartTimeInPast();
    endTime = endTime_;
    startTime = startTime_;
    token = token_;
    totalAmount = totalAmount_;
  }

  function setMerkleRoot(bytes32 merkleRoot_) public onlyOwner {
    merkleRoot = merkleRoot_;
  }

  function isClaimed(address account) public view returns (bool) {
    return claimedList[account] && claimedList[account] == true;
  }

  function _setClaimed(address account) private {
    claimedList[account] = true;
  }

  function start() public onlyOwner {
    if (IERC20(token).balanceOf(address(this)) < totalAmount) revert TotalAmountExceedsBalance();
    hasStarted = true;
  }

  function pause() public onlyOwner {
    hasStarted = false;
  }

  function unPause() public onlyOwner {
    hasStarted = true;
  }

  function claim(address account, uint256 amount, bytes32[] calldata merkleProof) public virtual {
    if (hasStarted == false) revert NotStarted();
    if (block.timestamp > endTime) revert ClaimWindowFinished();
    if (block.timestamp < startTime) revert ClaimWindowNotStarted();
    if (isClaimed(account)) revert AlreadyClaimed();
    if (IERC20(token).balanceOf(address(this)) < amount) revert AmountExceedsBalance();

    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(account, amount));
    if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

    // Mark it claimed and send the token.
    _setClaimed(account);
    IERC20(token).safeTransfer(account, amount);

    emit Claimed(account, amount);
  }

  function withdraw() external onlyOwner {
    if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
    IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
  }
}
