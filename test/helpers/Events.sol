// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract Events {
    event ClaimedSingle(address indexed account, address rewardAddress, uint256 amount);
    event Queued(uint256 timestamp);
    event JsonSpecCIDSet(string cid);
}
