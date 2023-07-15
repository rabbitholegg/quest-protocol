// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuest1155 {
    function singleClaim(address account) external;
    function queued() external view returns (bool);
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function rewardToken() external view returns (address);
    function tokenId() external view returns (uint256);
    function questFee() external view returns (uint256);
}
