// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuestUniversal {
    function queued() external view returns (bool);
    function endTime() external view returns (uint);
    function startTime() external view returns (uint);
    function singleClaim(address account_) external;
    function rewardToken() external view returns (address);
    function rewardAmountInWei() external view returns (uint);
}
