// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IQuestTerminalKey {
    function ownerOf(uint tokenId_) external view returns (address);

    function incrementUsedCount(uint tokenId_) external;

    function discounts(uint tokenId_) external view returns (uint16, uint16);
}
