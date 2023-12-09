// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract CalldataTest {
    string public name;

    event Name(string name);

    constructor(string memory name_) {
        name = name_;
    }

    function emitWithRead() external {
        emit Name(name);
    }

    function emitWithFromCalldata(string calldata name_) external {
        emit Name(name_);
    }

    function setName(string calldata name_) external {
        name = name_;
    }
}
