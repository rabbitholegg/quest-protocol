// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IQuestFactory } from "../interfaces/IQuestFactory.sol";

abstract contract QuestClaimable {
    function getQuestFactoryContract() public view virtual returns (IQuestFactory);

    function getQuestId() public view virtual returns (string memory);

    function claim() external payable {
        address ref_;
        IQuestFactory questFactoryContract = getQuestFactoryContract();
        string memory questId = getQuestId();

        (bytes32 txHash_, bytes32 r_, bytes32 vs_) = abi.decode(msg.data[4:], (bytes32, bytes32, bytes32));

        if (msg.data.length > 100) {
            assembly {
                ref_ := calldataload(100)
                ref_ := shr(96, ref_)
            }
        }

        IQuestFactory.QuestJsonData memory quest_ = questFactoryContract.questJsonData(questId);
        string memory jsonData_ = questFactoryContract.buildJsonString(txHash_, quest_.txHashChainId, quest_.actionType, quest_.questName);
        bytes memory claimData_ = abi.encode(msg.sender, ref_, questId, jsonData_);

        questFactoryContract.claimOptimized{value: msg.value}(abi.encodePacked(r_,vs_), claimData_);
    }
}

