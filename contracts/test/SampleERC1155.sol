// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1155} from "solady/tokens/ERC1155.sol";

contract SampleERC1155 is ERC1155 {
    // solhint-disable-next-line no-empty-blocks
    function uri(uint256) public pure virtual override returns (string memory) {}

    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts) public {
        _batchMint(to, ids, amounts, "0x0");
    }

    function mintSingle(address to, uint256 tokenId, uint256 amount) public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        _batchMint(to, ids, amounts, "0x0");
    }
}
