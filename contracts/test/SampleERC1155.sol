// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC1155} from "solady/src/tokens/ERC1155.sol";

contract SampleERC1155 is ERC1155 {
    // solhint-disable-next-line no-empty-blocks
    function uri(uint256) public pure virtual override returns (string memory) {}

    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts) public {
        _batchMint(to, ids, amounts, "0x0");
    }
}
