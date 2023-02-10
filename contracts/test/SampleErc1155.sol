// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract SampleErc1155 is ERC1155 {
    constructor() ERC1155('ipfs://cid/{id}.json') {
        _mint(msg.sender, 1, 100, '0x0');
    }
}
