// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "solady/src/tokens/ERC20.sol";

contract SampleERC20 is ERC20 {
    string internal _name;
    string internal _symbol;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        address owner_
    ) {
        _name = name_;
        _symbol = symbol_;
        _mint(owner_, initialSupply_);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
}