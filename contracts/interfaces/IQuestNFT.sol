// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

interface IQuestNFT {
    function initialize(
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        string memory questId_,
        uint16 questFee_,
        address protocolFeeRecipient_,
        address minterAdress_, // should always be the QuestFactory contract
        string memory jsonSpecCID_,
        string memory name_,
        string memory symbol_,
        string memory description_,
        string memory imageIPFSHash_
    ) external;
}
