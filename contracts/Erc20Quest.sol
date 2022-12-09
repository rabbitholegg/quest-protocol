//// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.15;
//
//import {Quest} from "./Quest.sol";
//import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
//
//contract Erc20Quest is Quest {
//    using SafeERC20Upgradeable for IERC20Upgradeable;
//
//    function claim() public virtual {
//        super(claim());
//        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, rewardAmountInWei);
//        super(_setClaimed(msg.sender));
//
//        emit Claimed(msg.sender, rewardAmountInWei);
//    }
//}
