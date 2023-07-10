// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuest {
startTime
endTime
singleClaim

rewardToken
rewardAmountInWei

    function isClaimed(uint256 tokenId_) external view returns (bool);

}
