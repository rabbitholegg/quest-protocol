// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";

contract SablierV2LockupLinearMock  {
    LockupLinear.CreateWithDurations public setData;
    function createWithDurations(LockupLinear.CreateWithDurations calldata params)
    external
    returns (uint256 streamId) {
        setData = params;
    }
}