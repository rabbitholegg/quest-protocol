// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Quest} from "./Quest.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract QuestFactory is Initializable, OwnableUpgradeable {

    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string name,
        string symbol,
        string contractType
    );

    // always be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __Ownable_init();
    }


    function createQuest(address rewardToken_,
        uint256 endTime_, uint256 startTime_, uint256 totalAmount_, string memory allowList_, uint256 rewardAmount_) public returns (address newQuest)
    {
        Quest newQuest = new Quest();

        newQuest.initialize(rewardToken_,
            endTime_,
            startTime_,
            totalAmount_,
            allowList_,
            rewardAmount_);

        return address(newQuest);
        //        emit QuestCreated(msg.sender, clone, _name, _symbol, _type);
    }
}