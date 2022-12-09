// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Quest} from "./Quest.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract QuestFactory is Initializable, OwnableUpgradeable {
    // Todo create mapping of questId to quest contracts
    // Todo create data structure of all quests

    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string contractType
    );

    // always be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __Ownable_init();
    }


    function createQuest(address rewardToken_,
        uint256 endTime_, uint256 startTime_, uint256 totalAmount_,
        string memory allowList_, uint256 rewardAmount_, string memory contractType,
        string memory questId_) public onlyOwner returns (address newQuest)
    {
        Quest newQuest = new Quest();

        newQuest.initialize(
            rewardToken_,
            endTime_,
            startTime_,
            totalAmount_,
            allowList_,
            rewardAmount_,
            questId_
        );

        emit QuestCreated(msg.sender, address(newQuest), contractType);
        return address(newQuest);
    }
}