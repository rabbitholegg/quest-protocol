// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {QuestFactoryBase} from './QuestFactoryBase.sol';
import {Quest1155} from './Quest1155.sol';

/// @title QuestFactoryZK
/// @author RabbitHole.gg
/// @dev This contract is used to create Quests and Quest1155s on ZKSync

contract QuestFactoryZK is QuestFactoryBase {
    function deploy1155Quest(address, string memory questId_) internal override(QuestFactoryBase) returns (address) {
        Quest1155 quest1155 = new Quest1155{salt: keccak256(abi.encodePacked(msg.sender, questId_))}();
        return address(quest1155);
    }
}
