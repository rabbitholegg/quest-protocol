// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/BoostPass.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {LibString} from "solady/utils/LibString.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract BoostPassTest is Test, TestUtils {
    using LibString for *;
    using LibString for address;
    using LibString for uint256;

    error AddressNotSigned();
    error TokenNotTransferable();
    error AddressAlreadyMinted();

    BoostPass internal boostPass;
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

        address boostPassImp = address(new BoostPass());
        factory = new ERC1967Factory();

        // initializeCallData is setting up: BoostPass.initialize(owner, claimSignerAddr);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address)", owner, claimSignerAddr);
        address boostPassAddr = factory.deployAndCall(boostPassImp, owner, initializeCallData);
        boostPass = BoostPass(boostPassAddr);

        vm.label(address(boostPass), "BoostPass");
    }

    function test_initialize() public {
        assertEq(boostPass.owner(), owner);
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);
        assertEq(boostPass.symbol(), "BP");
        assertEq(boostPass.name(), "Boost Pass");
    }

    function test_mint() public {
        bytes memory data = abi.encode(user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        boostPass.mint(signature, data);

        assertEq(boostPass.balanceOf(user), 1);
    }

    function test_mint__reverts_if_already_minted() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        boostPass.mint(signature, data);

        vm.expectRevert(abi.encodeWithSelector(AddressAlreadyMinted.selector));
        boostPass.mint(signature, data);
    }

    function test_mint__reverts_if_not_signed() public {
        bytes memory data = abi.encode(user);
        bytes memory badSignature = signHash(keccak256(data), 1);

        vm.expectRevert(abi.encodeWithSelector(AddressNotSigned.selector));
        boostPass.mint(badSignature, data);
    }

    function test_setClaimSignerAddress() public {
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);

        vm.prank(owner);
        boostPass.setClaimSignerAddress(owner);

        assertEq(boostPass.claimSignerAddress(), owner);
    }

    function test_tokenURI() public {
        bytes memory data = abi.encode(user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        boostPass.mint(signature, data);

        assertEq(boostPass.tokenURI(1), LibString.concat("https://api.rabbithole.gg/v1/boostpass/", user.toHexString()).concat("?id=").concat("1"));
    }

    function test_revert_if_transfer() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        boostPass.mint(signature, data);

        vm.expectRevert(abi.encodeWithSelector(TokenNotTransferable.selector));
        boostPass.transferFrom(user, owner, 1);
    }
}
