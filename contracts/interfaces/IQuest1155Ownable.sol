// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IOwnable} from "./IOwnable.sol";
import {IQuest1155} from "./IQuest1155.sol";

// solhint-disable-next-line no-empty-blocks
interface IQuest1155Ownable is IQuest1155, IOwnable {}
