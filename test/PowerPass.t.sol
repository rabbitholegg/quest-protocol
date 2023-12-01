// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/PowerPass.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract PowerPassTest is Test, TestUtils {
    error AddressNotSigned();
    error TokenNotTransferable();
    error AddressAlreadyMinted();

    PowerPass internal powerPass;
    ERC1967Factory internal factory;

    uint256 claimSignerPrivateKey;
    address internal claimSignerAddr;
    address internal owner;
    address internal user;

    function setUp() public virtual {
        owner = makeAddr("owner");
        user = makeAddr("user");
        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        claimSignerAddr = claimSigner.addr;

        address powerPassImp = address(new PowerPass());
        factory = new ERC1967Factory();

        // initializeCallData is setting up: PowerPass.initialize(owner);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address)", owner, claimSignerAddr);
        address powerPassAddr = factory.deployAndCall(powerPassImp, owner, initializeCallData);
        powerPass = PowerPass(powerPassAddr);

        vm.label(address(powerPass), "PowerPass");
    }

    function test_initialize() public {
        assertEq(powerPass.owner(), owner);
        assertEq(powerPass.claimSignerAddress(), claimSignerAddr);
        assertEq(powerPass.symbol(), "RHPP");
        assertEq(powerPass.name(), "RabbitHole Power Pass");
    }

    function test_mint() public {
        bytes memory data = abi.encode(user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        powerPass.mint(signature, data);

        assertEq(powerPass.balanceOf(user), 1);
    }

    function test_mint__reverts_if_already_minted() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        powerPass.mint(signature, data);

        vm.expectRevert(abi.encodeWithSelector(AddressAlreadyMinted.selector));
        powerPass.mint(signature, data);
    }

    function test_mint__reverts_if_not_signed() public {
        bytes memory data = abi.encode(user);
        bytes memory badSignature = signHash(keccak256(data), 1);

        vm.expectRevert(abi.encodeWithSelector(AddressNotSigned.selector));
        powerPass.mint(badSignature, data);
    }

    function test_setClaimSignerAddress() public {
        assertEq(powerPass.claimSignerAddress(), claimSignerAddr);

        vm.prank(owner);
        powerPass.setClaimSignerAddress(owner);

        assertEq(powerPass.claimSignerAddress(), owner);
    }

    function test_tokenURI() public {
        assertEq(powerPass.tokenURI(1), "https://api.rabbithole.gg/v1/powerpass/1");
    }

    function test_revert_if_transfer() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        powerPass.mint(signature, data);

        vm.expectRevert(abi.encodeWithSelector(TokenNotTransferable.selector));
        powerPass.transferFrom(user, owner, 1);
    }
}
