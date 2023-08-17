// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IQuestTerminalKey} from "./IQuestTerminalKey.sol";

interface IQuestTerminalKeyERC721 is IQuestTerminalKey, IERC721Upgradeable {}
