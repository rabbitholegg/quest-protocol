// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface ISoulbound20 {
    // Events
    event TransferAllowedSet(bool transferAllowed);

    // External functions
    function initialize(
        address owner_,
        string calldata name_,
        string calldata symbol_
    ) external;

    function mint(address to_, uint256 amount_) external;

    function setTransferAllowed(bool transferAllowed_) external;

    // External view functions
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);
}
