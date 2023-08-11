// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {QuestFactoryBase} from './QuestFactoryBase.sol';
import {Quest as QuestContract} from './Quest.sol';
import {Quest1155 as Quest1155Contract} from './Quest1155.sol';

/// @title QuestFactoryZK
/// @author RabbitHole.gg
/// @dev This contract is used to create Quests and Quest1155s on ZKSync
contract QuestFactoryZK is QuestFactoryBase {

    function deploy1155Quest(address, string memory questId_) internal override(QuestFactoryBase) returns (address quest1155) {
        Quest1155Contract quest1155Contract = new Quest1155Contract{salt: keccak256(abi.encodePacked(msg.sender, questId_))}();
        quest1155 = address(quest1155Contract);
    }

}
