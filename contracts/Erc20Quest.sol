// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Quest} from './Quest.sol';
import {QuestFactory} from './QuestFactory.sol';

contract Erc20Quest is Quest {
    using SafeERC20 for IERC20;
    uint256 public questFee;
    address public protocolFeeRecipient;
    QuestFactory public questFactoryContract;

    constructor(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        string memory allowList_,
        uint256 rewardAmountInWeiOrTokenId_,
        string memory questId_,
        address receiptContractAddress_,
        uint256 questFee_,
        address protocolFeeRecipient_,
        address factoryContractAddress_
    )
    Quest(
        rewardTokenAddress_,
        endTime_,
        startTime_,
        totalParticipants_,
        allowList_,
        rewardAmountInWeiOrTokenId_,
        questId_,
        receiptContractAddress_
    ) {
        questFee = questFee_;
        protocolFeeRecipient = protocolFeeRecipient_;
        questFactoryContract = QuestFactory(factoryContractAddress_);
        factoryContractAddress = factoryContractAddress_;
    }

    function maxTotalRewards() public view returns (uint256) {
        return totalParticipants * rewardAmountInWeiOrTokenId;
    }

    function maxProtocolReward() public view returns (uint256) {
        return maxTotalRewards() * questFee / 10_000;
    }

    function start() public override {
        if (IERC20(rewardToken).balanceOf(address(this)) < maxTotalRewards() + maxProtocolReward()) revert TotalAmountExceedsBalance();
        super.start();
    }

    function claim() public override returns (uint256) {
        uint redeemableTokenCount = super.claim();
        reedemedTokens += redeemableTokenCount;

        return redeemableTokenCount; // not used
    }

    function _transferRewards(uint256 amount_) internal override {
        IERC20(rewardToken).safeTransfer(msg.sender, amount_);
    }

    function _calculateRewards(uint256 redeemableTokenCount_) internal view override returns (uint256) {
        return redeemableTokenCount_ * rewardAmountInWeiOrTokenId;
    }

    function withdrawRemainingTokens(address to_) public override onlyOwner {
        super.withdrawRemainingTokens(to_);

        uint unclaimedTokens = (receiptRedeemers() - reedemedTokens) * rewardAmountInWeiOrTokenId;
        uint256 nonClaimableTokens = IERC20(rewardToken).balanceOf(address(this)) - protocolFee() - unclaimedTokens;
        IERC20(rewardToken).safeTransfer(to_, nonClaimableTokens);
    }

    function receiptRedeemers() public view returns (uint256) {
        return questFactoryContract.getNumberMinted(questId);
    }

    function protocolFee() public view returns (uint256) {
        return receiptRedeemers() * rewardAmountInWeiOrTokenId * questFee / 10_000;
    }

    function withdrawFee() public onlyStarted {
        IERC20(rewardToken).safeTransfer(protocolFeeRecipient, protocolFee());
    }
}


