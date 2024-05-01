// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {QuestFactory} from "./QuestFactory.sol";

interface IBlastPoints {
  function configurePointsOperator(address operator) external;
  function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
}

contract BlastQuestFactory is QuestFactory {
    function configurePointsOperator(address operatorAddress) external onlyOwner {
        address BlastPointsAddress = 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800; // BlastPoints Mainnet address
        IBlastPoints(BlastPointsAddress).configurePointsOperator(operatorAddress);
    }
}