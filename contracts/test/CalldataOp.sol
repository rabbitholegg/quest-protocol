// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract CalldataOp {
    bytes public name;

    event Name(bytes name);

    constructor(bytes memory name_) {
        name = name_;
    }

    function emitWithRead() external {
        emit Name(name);
    }

    function emitWithCalldata(bytes calldata name_) external {
        emit Name(name_);
    }

    function emitWithCalldataMemory(bytes memory name_) external {
        emit Name(name_);
    }

    function setName(bytes calldata name_) external {
        name = name_;
    }
}
