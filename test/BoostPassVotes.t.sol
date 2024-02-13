// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {BoostPass} from "../contracts/BoostPass.sol";
import {BoostPassVotes} from "../contracts/BoostPassVotes.sol";
import {MyGovernor} from "../contracts/test/MyGovernor.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {IVotes} from "openzeppelin-contracts/governance/utils/IVotes.sol";

// TODO: Make notes of which block the forked tests are running on
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
    MyGovernor internal myGovernor;

    uint256 claimSignerPrivateKey;
    address internal claimSignerAddr;
    address internal owner;
    address internal minter;
    uint256 internal sepoliaFork;
    uint256 internal arbitrumFork;

    function setUp() public virtual {
        string memory SEPOLIA_RPC_URL = vm.envString("ALCHEMY_SEPOLIA_RPC");
        // string memory ARBITRUM_RPC_URL = vm.envString("ALCHEMY_ARBITRUM_RPC");
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        // arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
   
        address boostPassAddr = 0x0Bd0E39db7F3557Ae9c071209b7B26808157a0Aa;
        boostPass = BoostPass(boostPassAddr);
        vm.label(address(boostPass), "BoostPass");

        vm.selectFork(sepoliaFork);
        owner = boostPass.owner();

        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        claimSignerAddr = claimSigner.addr;
       
        // deploy BoostPassVotes contract
        boostPassVotes = new BoostPassVotes(boostPassAddr);
        address boostPassVotesAddr = address(boostPassVotes);
        vm.label(boostPassVotesAddr, "BoostPassVotes");

        minter = makeAddr('minter');
        vm.deal(minter, 1 ether);

        // deploy MyGovernor contract
        myGovernor = new MyGovernor(IVotes(boostPassVotesAddr));
        address myGovernorAddr = address(myGovernor);
        vm.label(myGovernorAddr, "MyGovernor");

        // upgrade BoostPass contract
        factory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
        vm.startPrank(owner);
        factory.upgrade(boostPassAddr, address(new BoostPass()));
        vm.stopPrank();
    }

    function test_proposal_execution() public {
        vm.selectFork(sepoliaFork);

        assertEq(boostPassVotes.getVotes(minter), 0);

        // manually set claimSignerAddress so that we can mint on this fork
        vm.prank(owner);
        boostPass.setClaimSignerAddress(claimSignerAddr);
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);

        // mint a BoostPass
        bytes memory data = abi.encode(minter, address(0));
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        uint256 mintFee = boostPass.mintFee();
        vm.prank(minter);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.balanceOf(minter), 1);
        assertEq(boostPassVotes.getVotes(minter), 1);

        // use DAI and send it to the governor contract
        address daiAddress = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6;
        ERC20 DAI = ERC20(daiAddress);
        deal(address(DAI), address(myGovernor), 10 ether);


        // create proposal
        bytes memory transferCallData = abi.encodeWithSignature("transfer(address,uint256)", owner, 1 ether);
        vm.prank(owner);
        address[] memory targets = new address[](1);
        targets[0] = daiAddress;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = transferCallData;
        string memory description = "Proposal #1: Transfer DAI to the owner";
        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);

        // Cast votes
        uint256 snapshot = myGovernor.proposalSnapshot(proposalId);
        vm.warp(snapshot + 1);
        vm.prank(minter);
        myGovernor.castVote(proposalId, 1);

        // Execute proposal
        uint256 deadline = myGovernor.proposalDeadline(proposalId);
        vm.warp(deadline + 1);
        uint256 successfulProposalId = myGovernor.execute(targets, values, calldatas, keccak256(abi.encodePacked(description)));

        assertEq(successfulProposalId, proposalId);
        assertEq(DAI.balanceOf(owner), 1 ether);
    }
}
