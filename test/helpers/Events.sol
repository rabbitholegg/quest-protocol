// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract Events {
    event Queued(uint256 timestamp);

    // QuestFactory
    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string projectName,
        string questName,
        string questId,
        string questType,
        string actionType,
        uint32 chainId,
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