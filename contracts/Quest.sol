// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IQuest} from './interfaces/IQuest.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

contract Quest is Ownable, IQuest {
    RabbitHoleReceipt public immutable rabbitHoleReceiptContract;
    address public immutable rewardToken;
    uint256 public immutable endTime;
    uint256 public immutable startTime;
    uint256 public immutable totalParticipants;
    uint256 public immutable rewardAmountInWeiOrTokenId;
    bool public hasStarted;
    bool public isPaused;
    string public questId;
    uint256 public redeemedTokens;

    mapping(uint256 => bool) private claimedList;

    constructor(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_
    ) {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (startTime_ <= block.timestamp) revert StartTimeInPast();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = rewardTokenAddress_;
        totalParticipants = totalParticipants_;
        rewardAmountInWeiOrTokenId = rewardAmountInWeiOrTokenId_;
        questId = questId_;
        rabbitHoleReceiptContract = RabbitHoleReceipt(receiptContractAddress_);
        redeemedTokens = 0;
    }

    function start() public virtual onlyOwner {
        isPaused = false;
        hasStarted = true;
    }

    function pause() public onlyOwner onlyStarted {
        isPaused = true;
    }

    function unPause() public onlyOwner onlyStarted {
        isPaused = false;
    }

    function _setClaimed(uint256[] memory tokenIds_) private {
        for (uint i = 0; i < tokenIds_.length; i++) {
            claimedList[tokenIds_[i]] = true;
        }
    }

    modifier onlyAdminWithdrawAfterEnd() {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        _;
    }

    modifier onlyStarted() {
        if (!hasStarted) revert NotStarted();
        _;
    }

    modifier onlyQuestActive()  {
        if (!hasStarted) revert NotStarted();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        _;
    }

    function claim() public virtual onlyQuestActive {
        if (isPaused) revert QuestPaused();

        uint[] memory tokens = rabbitHoleReceiptContract.getOwnedTokenIdsOfQuest(questId, msg.sender);

        if (tokens.length == 0) revert NoTokensToClaim();

        uint256 redeemableTokenCount = 0;
        for (uint i = 0; i < tokens.length; i++) {
            if (!isClaimed(tokens[i])) {
                redeemableTokenCount++;
            }
        }

        if (redeemableTokenCount == 0) revert AlreadyClaimed();

        uint256 totalRedeemableRewards = _calculateRewards(redeemableTokenCount);
        _setClaimed(tokens);
        _transferRewards(totalRedeemableRewards);
        redeemedTokens += redeemableTokenCount;

        emit Claimed(msg.sender, totalRedeemableRewards);
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal virtual returns (uint256) {
        revert MustImplementInChild();
    }

    function _transferRewards(uint256 amount_) internal virtual {
        revert MustImplementInChild();
    }

    function isClaimed(uint256 tokenId_) public view returns (bool) {
        return claimedList[tokenId_] == true;
    }

    function withdrawRemainingTokens(address to_) public virtual onlyOwner onlyAdminWithdrawAfterEnd {}
}
