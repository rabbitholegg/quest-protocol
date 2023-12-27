// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import "../contracts/SoulBound20.sol";

contract SoulBound20Test is Test {
    using LibClone for address;

    SoulBound20 soulBound;
    address owner = makeAddr(("owner"));
    address minter = makeAddr(("minter"));
    address user1 = makeAddr(("user1"));
    address user2 = makeAddr(("user2 "));

    function setUp() public {
        address soulBoundAddress = address(new SoulBound20()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT")));
        soulBound = SoulBound20(soulBoundAddress);
        soulBound.initialize(owner, minter, "SoulBound Token", "SBT");
    }

    function test_mint() public {
        vm.prank(minter);
        soulBound.mint(user1, 100);

        assertEq(soulBound.balanceOf(user1), 100);
    }

    function test_mint_revertIf_not_minter() public {
        soulBound.mint(user1, 100);
        vm.expectRevert(SoulBound20.OnlyMinter.selector);
    }

    function test_setMinterAddress() public {
        vm.prank(owner);
        soulBound.setMinterAddress(user1);
        assertEq(soulBound.minterAddress(), user1);
    }

    function test_setMinterAddress_revertIf_notOwner() public {
        vm.prank(user1);
        soulBound.setMinterAddress(user2);
        vm.expectRevert(Ownable.Unauthorized.selector);
    }

    function test_transfer_revertIf_notAllowed() public {
        vm.prank(minter);
        soulBound.mint(user1, 100);

        vm.expectRevert(SoulBound20.TransferNotAllowed.selector);
        soulBound.transfer(user2, 50);
    }

    function test_setTransferAllowed() public {
        vm.prank(owner);
        soulBound.setTransferAllowed(true);
        assertTrue(soulBound.transferAllowed());

        vm.prank(minter);
        soulBound.mint(user1, 100);
        vm.prank(user1);
        soulBound.transfer(user2, 50);
    }
}
