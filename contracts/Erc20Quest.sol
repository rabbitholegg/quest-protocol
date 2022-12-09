// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IQuest} from "./interfaces/IQuest.sol";

contract Erc20Quest is Initializable, OwnableUpgradeable, IQuest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalAmount;
    uint256 public rewardAmountInWei;
    bool public hasStarted;
    bool public isPaused;
    string public allowList;
    string public questId;

    mapping(uint256 => bool) private claimedList;

    function initialize(
        address erc20TokenAddress_, uint256 endTime_,
        uint256 startTime_, uint256 totalAmount_, string memory allowList_,
        uint256 rewardAmountInWei_, string memory questId_) public initializer {
        __Ownable_init();
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (startTime_ <= block.timestamp) revert StartTimeInPast();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = erc20TokenAddress_;
        totalAmount = totalAmount_;
        rewardAmountInWei = rewardAmountInWei_;
        allowList = allowList_;
        questId = questId_;
    }

    function start() public onlyOwner {
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < totalAmount) revert TotalAmountExceedsBalance();
        isPaused = false;
        hasStarted = true;
    }

    function pause() public onlyOwner {
        if (hasStarted == false) revert NotStarted();
        isPaused = true;
    }

    function unPause() public onlyOwner {
        if (hasStarted == false) revert NotStarted();
        isPaused = false;
    }

    function setAllowList(string memory allowList_) public onlyOwner {
        allowList = allowList_;
    }

    function _setClaimed(uint256 tokenId_) private {
        claimedList[tokenId_] = true;
    }

    function claim() public virtual {
        if (hasStarted == false) revert NotStarted();
        if (isPaused == true) revert QuestPaused();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < rewardAmountInWei) revert AmountExceedsBalance();


//        if (isClaimed(account)) revert AlreadyClaimed();

        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, rewardAmountInWei);
//        _setClaimed(account);

        emit Claimed(msg.sender, rewardAmountInWei);
    }

    function isClaimed(address account) public view returns (bool) {
        return true;
//        return claimedList[tokenId] && claimedList[account] == true;
    }

    function withdraw() public onlyOwner {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, IERC20Upgradeable(rewardToken).balanceOf(address(this)));
    }
}
