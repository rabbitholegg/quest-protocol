// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {QuestFactoryBase} from './QuestFactoryBase.sol';
import {LibClone} from 'solady/src/utils/LibClone.sol';

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create Quests and Quest1155s on the EVM
contract QuestFactory is QuestFactoryBase {
    using LibClone for address;

    function deploy1155Quest(address erc1155QuestAddress, string memory questId_) internal override(QuestFactoryBase) returns (address quest1155) {
        quest1155 = erc1155QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_)));
    }

}
