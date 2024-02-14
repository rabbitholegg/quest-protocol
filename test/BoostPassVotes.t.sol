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

    BoostPass internal boostPass;
    ERC1967Factory internal factory;
    BoostPassVotes internal boostPassVotes;
    MyGovernor internal myGovernor;
    ERC20 internal dai;

    uint256 claimSignerPrivateKey;
    address internal claimSignerAddr;
    address internal owner;
    address internal minter;
    address internal delegatee;
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
        delegatee = makeAddr('delegatee');
        vm.deal(minter, 1 ether);
        vm.deal(delegatee, 1 ether);

        // deploy MyGovernor contract
        myGovernor = new MyGovernor(IVotes(boostPassVotesAddr));
        address myGovernorAddr = address(myGovernor);
        vm.label(myGovernorAddr, "MyGovernor");

        assertEq(boostPassVotes.getVotes(minter), 0);

        // upgrade BoostPass contract
        factory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
        vm.startPrank(owner);
        factory.upgrade(boostPassAddr, address(new BoostPass()));

        // manually set claimSignerAddress so that we can mint on this fork
        boostPass.setClaimSignerAddress(claimSignerAddr);
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);

        vm.stopPrank();

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
        address daiAddress = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6; // https://sepolia.etherscan.io/address/0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6
        dai = ERC20(daiAddress);
        deal(address(dai), address(myGovernor), 10 ether);
    }
  
    function test_proposal_execution() public {
        vm.selectFork(sepoliaFork);

        // create proposal
        bytes memory transferCallData = abi.encodeWithSignature("transfer(address,uint256)", owner, 1 ether);
        vm.prank(owner);
        address[] memory targets = new address[](1);
        targets[0] = address(dai);
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
        assertEq(dai.balanceOf(owner), 1 ether);
    }

    function test_delegate() public {
        vm.selectFork(sepoliaFork);

        // delegate votes
        vm.prank(minter);
        boostPassVotes.delegate(delegatee);
        assertEq(boostPassVotes.delegates(minter), delegatee);
        assertEq(boostPassVotes.getVotes(delegatee), 1);

        // delegatee should mint and increase voting power
        bytes memory data = abi.encode(delegatee, address(0));
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        uint256 mintFee = boostPass.mintFee();
        vm.prank(delegatee);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.balanceOf(delegatee), 1);
        assertEq(boostPassVotes.getVotes(delegatee), 2);
    }
}
