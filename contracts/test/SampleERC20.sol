// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solady/tokens/ERC20.sol";

contract SampleERC20 is ERC20 {
    string internal _name;
    string internal _symbol;

    // solhint-disable-next-line func-visibility
    constructor(string memory name_, string memory symbol_, uint256 initialSupply_, address owner_) {
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

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }
}
