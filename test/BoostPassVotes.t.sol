// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/BoostPass.sol";
import "../contracts/BoostPassVotes.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {LibString} from "solady/utils/LibString.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract BoostPassVotesTest is Test, TestUtils {
    using LibString for *;
    using LibString for address;
    using LibString for uint256;

    error AddressNotSigned();
    error TokenNotTransferable();
    error AddressAlreadyMinted();
    error InvalidMintFee();
    error ToAddressIsNotSender();
    
    // This error exists in Solady ERC721.sol
    error TokenDoesNotExist();

    event BoostPassMinted(address indexed minter, address indexed referrer, uint256 referrerFee, uint256 treasuryFee, uint256 tokenId);

    BoostPass internal boostPass;
    ERC1967Factory internal factory;
    BoostPassVotes internal boostPassVotes;

    uint256 claimSignerPrivateKey;
    address internal claimSignerAddr;
    address internal owner;
    uint256 internal sepoliaFork;
    uint256 internal arbitrumFork;

    function setUp() public virtual {
        string memory SEPOLIA_RPC_URL = vm.envString("ALCHEMY_SEPOLIA_RPC");
        string memory ARBITRUM_RPC_URL = vm.envString("ALCHEMY_ARBITRUM_RPC");
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
   
        address boostPassAddr = 0x0Bd0E39db7F3557Ae9c071209b7B26808157a0Aa;
        boostPass = BoostPass(boostPassAddr);
        vm.label(address(boostPass), "BoostPass");

        vm.selectFork(sepoliaFork);
        owner = boostPass.owner();

        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        claimSignerAddr = claimSigner.addr;
       
        address boostPassVotesAddr = address(new BoostPassVotes(boostPassAddr));
        boostPassVotes = BoostPassVotes(boostPassVotesAddr);
        vm.label(boostPassVotesAddr, "BoostPassVotes");
    }

    function test_change_ownership() public {
        vm.prank(owner);
        boostPass.setClaimSignerAddress(claimSignerAddr);
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);
    }

    function test_balanceOf() public {
        vm.selectFork(sepoliaFork);
        address sepoliaMinter = 0xDcfFb96b8193b7B3aF51333a68097F40a7A09774;
        assertEq(boostPass.balanceOf(sepoliaMinter), 1);

        // vm.selectFork(arbitrumFork);
        // address arbitrumMinter = 0xfEC00C9B109FdbB7E504c5Ad570544a617cC9aaE;
        // assertEq(boostPass.balanceOf(arbitrumMinter), 1);
    }

    function test_random_stuff() public {
        vm.selectFork(sepoliaFork);
        assertEq(boostPassVotes.CLOCK_MODE(), "mode=timestamp");
        assertEq(boostPassVotes.clock(), block.timestamp);
        assertEq(boostPassVotes.getVotes(0xDcfFb96b8193b7B3aF51333a68097F40a7A09774), 1);
    }
   
}
