// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IOwnable} from "./IOwnable.sol";
import {IQuest} from "./IQuest.sol";

interface IQuestOwnable is IQuest, IOwnable {}
