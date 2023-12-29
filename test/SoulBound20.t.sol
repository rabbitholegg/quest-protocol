// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Soulbound20, OwnableRoles} from "../contracts/Soulbound20.sol";

contract Soulbound20Test is Test {
    using LibClone for address;
    error Unauthorized();

    Soulbound20 soulbound;
    address owner = makeAddr(("owner"));
    address minter = makeAddr(("minter"));
    address user1 = makeAddr(("user1"));
    address user2 = makeAddr(("user2 "));

    function setUp() public {
        address soulboundAddress = address(new Soulbound20()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT")));
        soulbound = Soulbound20(soulboundAddress);
        soulbound.initialize(owner, "Soulbound Token", "SBT");
        vm.prank(owner);
        soulbound.grantRoles(minter, 1);
    }

    function test_initialize() public {
        assertEq(soulbound.owner(), owner);
        assertEq(soulbound.minterAddress(), minter);
        assertEq(soulbound.name(), "Soulbound Token");
        assertEq(soulbound.symbol(), "SBT");
    }

    function test_mint() public {
        vm.prank(minter);
        soulbound.mint(user1, 100);

        assertEq(soulbound.balanceOf(user1), 100);
    }

    function test_mint_revertIf_not_minter() public {
        vm.expectRevert(Unauthorized.selector);
        soulbound.mint(user1, 100);
    }

    function test_transfer_revertIf_notAllowed() public {
        vm.prank(minter);
        soulbound.mint(user1, 100);

        vm.expectRevert(Soulbound20.TransferNotAllowed.selector);
        soulbound.transfer(user2, 50);
    }

    function test_setTransferAllowed() public {
        vm.prank(owner);
        soulbound.setTransferAllowed(true);
        assertTrue(soulbound.transferAllowed());

        vm.prank(minter);
        soulbound.mint(user1, 100);
        vm.prank(user1);
        soulbound.transfer(user2, 50);
    }
}
