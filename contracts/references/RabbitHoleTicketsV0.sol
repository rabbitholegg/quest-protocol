// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RabbitHoleTicketsV0 is Initializable, Ownable {
    address public royaltyRecipient;
    address public minterAddress;
    uint256 public royaltyFee;
    string public imageIPFSCID;
    string public animationUrlIPFSCID;
}
