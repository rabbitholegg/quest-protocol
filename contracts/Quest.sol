// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IQuest} from "./interfaces/IQuest.sol";

contract Quest is Initializable, OwnableUpgradeable, IQuest {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public token;
  uint256 public endTime;
  uint256 public startTime;
  uint256 public totalAmount;
  bytes32 public merkleRoot;
  bool public hasStarted;
  string public allowList;

  event QuestCreated(
//    address indexed creator,
//    address indexed contractAddress,
//    string name,
//    string symbol,
//    string contractType
  );

  mapping(address => bool) private claimedList;

  function initialize(address token_, uint256 endTime_, uint256 startTime_, uint256 totalAmount_, string memory allowList_)  public initializer {
    __Ownable_init();
    if (endTime_ <= block.timestamp) revert EndTimeInPast();
    if (startTime_ <= block.timestamp) revert StartTimeInPast();
    endTime = endTime_;
    startTime = startTime_;
    token = token_;
    totalAmount = totalAmount_;
    allowList = allowList_;
  }

  function start() public onlyOwner {
    // not sure this is needed -> someone could just call unPause
    //    if (IERC20Upgradeable(token).balanceOf(address(this)) < totalAmount) revert TotalAmountExceedsBalance();
    hasStarted = true;
  }

  function pause() public onlyOwner {
    hasStarted = false;
  }

  function unPause() public onlyOwner {
    hasStarted = true;
  }

  function setMerkleRoot(bytes32 merkleRoot_) public onlyOwner {
    merkleRoot = merkleRoot_;
  }

  function _setClaimed(address account) private {
    claimedList[account] = true;
  }

  function claim(address account, uint256 amount, bytes32[] calldata merkleProof) public virtual {
    if (hasStarted == false) revert NotStarted();
    if (block.timestamp < startTime) revert ClaimWindowNotStarted();
    if (isClaimed(account)) revert AlreadyClaimed();
    if (IERC20Upgradeable(token).balanceOf(address(this)) < amount) revert AmountExceedsBalance();

    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(account, amount));
    if (!MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

    // Mark it claimed and send the token.
    IERC20Upgradeable(token).safeTransfer(account, amount);
    _setClaimed(account);

    emit Claimed(account, amount);
  }

  function isClaimed(address account) public view returns (bool) {
    return claimedList[account] && claimedList[account] == true;
  }

  function withdraw() public onlyOwner {
    if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
    IERC20Upgradeable(token).safeTransfer(msg.sender, IERC20Upgradeable(token).balanceOf(address(this)));
  }
}
