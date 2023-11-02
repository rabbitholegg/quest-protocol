// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract Events {
    event Queued(uint256 timestamp);
    event JsonSpecCIDSet(string cid);

    // QuestFactory
    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string questType,
        address rewardToken,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId
    );
    event QuestCreatedWithAction(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId,
        string actionSpec
    );
}