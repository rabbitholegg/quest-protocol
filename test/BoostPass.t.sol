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
    error ToAddressIsNotSender();

    event BoostPassMinted(address indexed minter, address indexed referrer, uint256 referrerFee, uint256 treasuryFee, uint256 tokenId);

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

        vm.deal(user, 1 ether);

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
        bytes memory data = abi.encode(user, address(0));
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        uint256 referralFee = 0;
        uint256 treasuryFee = mintFee;
        uint256 tokenId = 1; // assume this is the first mint

        vm.expectEmit();
        emit BoostPassMinted(user, address(0), referralFee, treasuryFee, tokenId);

        vm.prank(user);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.balanceOf(user), 1);
        assertEq(address(treasuryAddress).balance, mintFee);
    }

    function test_mint_with_referrer() public {
        bytes memory data = abi.encode(user, referrerAddress);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        uint256 referralFee = mintFee / 2;
        uint256 treasuryFee = mintFee - referralFee;
        uint256 tokenId = 1; // assume this is the first mint

        vm.expectEmit();
        emit BoostPassMinted(user, referrerAddress, referralFee, treasuryFee, tokenId);

        vm.prank(user);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.balanceOf(user), 1);

        assertEq(address(treasuryAddress).balance, treasuryFee);
        assertEq(address(referrerAddress).balance, referralFee);
    }

    function test_mint_with_referrer_as_minter() public {
        bytes memory data = abi.encode(user, user);
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);

        uint256 userBalanceBefore = address(user).balance;

        uint256 referralFee = 0;
        uint256 treasuryFee = mintFee;
        uint256 tokenId = 1; // assume this is the first mint

        vm.expectEmit();
        emit BoostPassMinted(user, address(0), referralFee, treasuryFee, tokenId);

        vm.prank(user);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.balanceOf(user), 1);

        assertEq(address(treasuryAddress).balance, mintFee);
        assertEq(address(user).balance, userBalanceBefore - mintFee);
    }

    function test_mint__reverts_if_already_minted() public {
        bytes memory data = abi.encode(user, address(0));
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        vm.startPrank(user);
        boostPass.mint{value: mintFee}(signature, data);

        vm.expectRevert(abi.encodeWithSelector(AddressAlreadyMinted.selector));
        boostPass.mint{value: mintFee}(signature, data);
        vm.stopPrank();
    }

    function test_mint__reverts_if_not_signed() public {
        bytes memory data = abi.encode(user, address(0));
        bytes memory badSignature = signHash(keccak256(data), 1);

        vm.expectRevert(abi.encodeWithSelector(AddressNotSigned.selector));
        vm.prank(user);
        boostPass.mint{value: mintFee}(badSignature, data);
    }

    function test_mint__reverts_if_not_enough_fee() public {
        bytes memory data = abi.encode(user, address(0));
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(InvalidMintFee.selector));
        vm.prank(user);
        boostPass.mint{value: mintFee - 1}(signature, data);
    }

    function test_mint__reverts_if_to_address_is_not_sender() public {
        bytes memory data = abi.encode(owner, address(0));
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(ToAddressIsNotSender.selector));
        vm.prank(user);
        boostPass.mint{value: mintFee}(signature, data);
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
        bytes memory data = abi.encode(user, address(0));
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        vm.prank(user);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.tokenURI(1), LibString.concat("https://api.rabbithole.gg/v1/boostpass/", user.toHexString()).concat("?id=").concat("1"));
    }

    function test_revert_if_transfer() public {
        bytes memory data = abi.encode(user, address(0));
        bytes memory signature = signHash(keccak256(data), claimSignerPrivateKey);

        vm.prank(user);
        boostPass.mint{value: mintFee}(signature, data);

        vm.expectRevert(abi.encodeWithSelector(TokenNotTransferable.selector));
        boostPass.transferFrom(user, owner, 1);
    }
}
