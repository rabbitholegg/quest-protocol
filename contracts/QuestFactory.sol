// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Erc20Quest} from './Erc20Quest.sol';
import {Erc1155Quest} from './Erc1155Quest.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

contract QuestFactory is Initializable, OwnableUpgradeable {
    error QuestIdUsed();

    mapping(string => address) public questAddressForQuestId;

    // Todo create data structure of all quests

    event QuestCreated(address indexed creator, address indexed contractAddress, string contractType);

    // always be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __Ownable_init();
    }

    function createQuest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalAmount_,
        string memory allowList_,
        uint256 rewardAmount_,
        string memory contractType_,
        string memory questId_,
        address receiptContractAddress_
    ) public onlyOwner returns (address) {
        if (questAddressForQuestId[questId_] != address(0)) revert QuestIdUsed();

        if (keccak256(abi.encodePacked(contractType_)) == keccak256(abi.encodePacked('erc20'))) {
            Erc20Quest newQuest = new Erc20Quest();
            newQuest.initialize(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalAmount_,
                allowList_,
                rewardAmount_,
                questId_,
                receiptContractAddress_
            );

            emit QuestCreated(msg.sender, address(newQuest), contractType_);
            questAddressForQuestId[questId_] = address(newQuest);
            return address(newQuest);
        }
        // TODO: Add 1155

        return address(0);
    }
}
