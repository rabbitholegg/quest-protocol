// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

abstract contract LegacyStorage {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    uint256[50] private __gap;
    address private _owner;
    uint256[49] private __gap1;
    uint256[50] private __gap2;
    mapping(bytes32 => RoleData) private _roles;
    uint256[49] private __gap3;
}
