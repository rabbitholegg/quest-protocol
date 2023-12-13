// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ForceTransfer {
    function forceTransfer(address _to) public payable {
        SafeTransferLib.forceSafeTransferETH(_to, msg.value);
    }
}