// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IOwnable {
    // Events
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event OwnershipHandoverRequested(address indexed pendingOwner);
    event OwnershipHandoverCanceled(address indexed pendingOwner);

    // Update functions
    function transferOwnership(address newOwner) external payable;
    function renounceOwnership() external payable;
    function requestOwnershipHandover() external payable;
    function cancelOwnershipHandover() external payable;
    function completeOwnershipHandover(address pendingOwner) external payable;

    // Read functions
    function owner() external view returns (address);
    function ownershipHandoverExpiresAt(address pendingOwner) external view returns (uint256);
}
