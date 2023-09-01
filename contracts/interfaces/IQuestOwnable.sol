// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IOwnable} from "./IOwnable.sol";
import {IQuest} from "./IQuest.sol";

// solhint-disable-next-line no-empty-blocks
interface IQuestOwnable is IQuest, IOwnable {}
