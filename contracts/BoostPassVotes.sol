// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {BoostPass} from "./BoostPass.sol";
import {SafeCastLib} from 'solady/utils/SafeCastLib.sol';
import {IVotes} from "openzeppelin-contracts/governance/utils/IVotes.sol";
// import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";

contract BoostPassVotes is BoostPass, IVotes {
    address boostPassAddress;

    constructor(address boostPassAddress_) {
        boostPassAddress = boostPassAddress_;
    }

    function clock() public view returns (uint48) {
        return SafeCastLib.toUint48(block.timestamp);
    }

    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
    }

    function getVotes(address account) external view returns (uint256) {
        return BoostPass(boostPassAddress).balanceOf(account);
    }

    function getPastVotes(address account, uint256 timepoint) public view returns (uint256) {
        // FIXME: actually return past votes here
        return BoostPass(boostPassAddress).balanceOf(account);
    }

    function getPastTotalSupply(uint256 timepoint) public view returns (uint256) {
        // FIXME: actually return past total supply here
        return BoostPass(boostPassAddress).mintFee();
    }

    function delegates(address account) public view returns (address) {
        // FIXME: actually return delegates here
        return BoostPass(boostPassAddress).owner();
    }

    function delegate(address delegatee) public {
        // FIXME: implement delegate here
    }

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) public {
        // FIXME: implement delegateBySig here
    }
}
