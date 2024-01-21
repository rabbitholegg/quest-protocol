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
    error InvalidMintFee();

    BoostPass internal boostPass;
    ERC1967Factory internal factory;

    uint256 claimSignerPrivateKey;
    address internal claimSignerAddr;
    address internal owner;
    address internal user;
    uint256 public mintFee;
    address public treasuryAddress;
    address public referrerAddress;

    function setUp() public virtual {
        owner = makeAddr("owner");
        user = makeAddr("user");
        mintFee = 2000000000000000;
        treasuryAddress = makeAddr("treasuryAddress");
        referrerAddress = makeAddr("referrerAddress");
        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        claimSignerAddr = claimSigner.addr;

        address boostPassImp = address(new BoostPass());
        factory = new ERC1967Factory();

        // initializeCallData is setting up: BoostPass.initialize(owner, claimSignerAddr, mintFee, treasuryAddress);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address,uint256,address)", owner, claimSignerAddr, mintFee, treasuryAddress);
        address boostPassAddr = factory.deployAndCall(boostPassImp, owner, initializeCallData);
        boostPass = BoostPass(boostPassAddr);

        vm.label(address(boostPass), "BoostPass");
    }

    function test_initialize() public {
        assertEq(boostPass.owner(), owner);
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);
        assertEq(boostPass.symbol(), "BP");
        assertEq(boostPass.name(), "Boost Pass");
        assertEq(boostPass.mintFee(), mintFee);
        assertEq(boostPass.treasuryAddress(), treasuryAddress);
    }

    function test_mint() public {
        bytes memory data = abi.encode(user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        boostPass.mint{value: mintFee}(signature, data, address(0));

        assertEq(boostPass.balanceOf(user), 1);
        assertEq(address(treasuryAddress).balance, mintFee);
    }

    function test_mint_with_referrer() public {
        bytes memory data = abi.encode(user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        boostPass.mint{value: mintFee}(signature, data, referrerAddress);

        assertEq(boostPass.balanceOf(user), 1);

        uint256 referralFee = mintFee / 2;
        assertEq(address(treasuryAddress).balance, mintFee - referralFee);
        assertEq(address(referrerAddress).balance, referralFee);
    }

    function test_mint__reverts_if_already_minted() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        boostPass.mint{value: mintFee}(signature, data, address(0));

        vm.expectRevert(abi.encodeWithSelector(AddressAlreadyMinted.selector));
        boostPass.mint{value: mintFee}(signature, data, address(0));
    }

    function test_mint__reverts_if_not_signed() public {
        bytes memory data = abi.encode(user);
        bytes memory badSignature = signHash(keccak256(data), 1);

        vm.expectRevert(abi.encodeWithSelector(AddressNotSigned.selector));
        boostPass.mint{value: mintFee}(badSignature, data, address(0));
    }

    function test_mint__reverts_if_not_enough_fee() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(InvalidMintFee.selector));
        boostPass.mint{value: mintFee - 1}(signature, data, address(0));
    }

    function test_setClaimSignerAddress() public {
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);

        vm.prank(owner);
        boostPass.setClaimSignerAddress(owner);

        assertEq(boostPass.claimSignerAddress(), owner);
    }

    function test_setMintFee() public {
        assertEq(boostPass.mintFee(), mintFee);

        vm.prank(owner);
        boostPass.setMintFee(100);

        assertEq(boostPass.mintFee(), 100);
    }

    function test_setTreasuryAddress() public {
        assertEq(boostPass.treasuryAddress(), treasuryAddress);

        vm.prank(owner);
        boostPass.setTreasuryAddress(owner);

        assertEq(boostPass.treasuryAddress(), owner);
    }

    function test_tokenURI() public {
        bytes memory data = abi.encode(user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        boostPass.mint{value: mintFee}(signature, data, address(0));

        assertEq(boostPass.tokenURI(1), LibString.concat("https://api.rabbithole.gg/v1/boostpass/", user.toHexString()).concat("?id=").concat("1"));
    }

    function test_revert_if_transfer() public {
        bytes memory data = abi.encode(user);
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        boostPass.mint{value: mintFee}(signature, data, address(0));

        vm.expectRevert(abi.encodeWithSelector(TokenNotTransferable.selector));
        boostPass.transferFrom(user, owner, 1);
    }
}
