// SPDX-License-Identifier: MIT
// from https://solidity-by-example.org/new-contract/
pragma solidity ^0.8.17;

contract Car {
    address public owner;
    string public model;
    address public carAddr;

    constructor(address _owner, string memory _model) payable {
        owner = _owner;
        model = _model;
        carAddr = address(this);
    }
}
