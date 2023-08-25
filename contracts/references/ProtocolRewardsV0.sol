// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ProtocolRewardsV0 is Initializable, Ownable {
    mapping(address => uint256) public balanceOf;
    uint256 public totalBalance;
}
