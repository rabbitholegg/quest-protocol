// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {LockupLinear} from "sablier/types/DataTypes.sol";

contract SablierV2LockupLinearMock  {
    LockupLinear.CreateWithDurations public setData;
    function createWithDurations(LockupLinear.CreateWithDurations calldata params)
    external {
        setData = params;
    }
}