// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IQuest} from './interfaces/IQuest.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

contract Quest is Ownable, IQuest {
    RabbitHoleReceipt public rabbitholeReceiptContract;

    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalAmount;
    uint256 public rewardAmountInWeiOrTokenId;
    bool public hasStarted;
    bool public isPaused;
    string public allowList;
    string public questId;

    mapping(uint256 => bool) private claimedList;

    constructor(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalAmount_,
        string memory allowList_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_
    ) {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (startTime_ <= block.timestamp) revert StartTimeInPast();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = rewardTokenAddress_;
        totalAmount = totalAmount_;
        rewardAmountInWeiOrTokenId = rewardAmountInWeiOrTokenId_;
        allowList = allowList_;
        questId = questId_;
        rabbitholeReceiptContract = RabbitHoleReceipt(receiptContractAddress_);
    }

    function start() public virtual onlyOwner {
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

    function _setClaimed(uint256[] memory tokenIds_) private {
        for (uint i = 0; i < tokenIds_.length; i++) {
            claimedList[tokenIds_[i]] = true;
        }
    }

    function getClaimableTokenIds(uint[] memory _tokenIds) public view returns (uint[] memory) {
        uint msgSenderBalance = _tokenIds.length;
        uint[] memory tokenIdsForClaim = new uint[](msgSenderBalance);
        uint foundTokens = 0;

        for (uint i = 0; i < msgSenderBalance; i++) {
            if (rabbitholeReceiptContract.tokenIdCanClaim(_tokenIds[i])) {
                tokenIdsForClaim[i] = _tokenIds[i];
                foundTokens++;
            }
        }

        uint[] memory filteredTokens = new uint[](foundTokens);
        uint filterTokensIndexTracker = 0;

        for (uint i = 0; i < msgSenderBalance; i++) {
            if (tokenIdsForClaim[i] > 0) {
                filteredTokens[filterTokensIndexTracker] = tokenIdsForClaim[i];
                filterTokensIndexTracker++;
            }
        }

        return filteredTokens;
    }

    function claim() public virtual {
        if (hasStarted == false) revert NotStarted();
        if (isPaused == true) revert QuestPaused();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();

        uint[] memory questTokens = rabbitholeReceiptContract.getOwnedTokenIdsOfQuest(questId, msg.sender);
        uint[] memory tokens = getClaimableTokenIds(questTokens);

        if (tokens.length == 0) revert NoTokensToClaim();

        uint256 redeemableTokenCount = 0;

        for (uint i = 0; i < tokens.length; i++) {
            if (!isClaimed(tokens[i])) {
                redeemableTokenCount++;
            }
        }

        if (redeemableTokenCount == 0) revert AlreadyClaimed();

        uint256 totalReedemableRewards = _calculateRewards(redeemableTokenCount);

        _setClaimed(tokens);

        _transferRewards(totalReedemableRewards);

        emit Claimed(msg.sender, totalReedemableRewards);
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal virtual returns (uint256) {
        // override this function to calculate rewards
    }

    function _transferRewards(uint256 amount_) internal virtual {
        // override this function to transfer rewards
    }

    function isClaimed(uint256 tokenId_) public view returns (bool) {
        return claimedList[tokenId_] && claimedList[tokenId_] == true;
    }

    function withdraw() public virtual onlyOwner {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
    }
}
