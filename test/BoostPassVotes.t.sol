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
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

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
    address internal minterAddress;
    address internal delegatee;
    uint256 internal sepoliaFork;
    uint256 internal arbitrumFork;

    Vm.Wallet internal minter;

    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);
    error VotesExpiredSignature(uint256 expiry);
    error MsgSenderIsNotBoostPass();
    error MsgSenderIsNotBoostPassOwner();

    function setUp() public virtual {
        string memory SEPOLIA_RPC_URL = vm.envString("ALCHEMY_SEPOLIA_RPC");
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);

        // string memory ARBITRUM_RPC_URL = vm.envString("ALCHEMY_ARBITRUM_RPC");
        // arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
   
        vm.selectFork(sepoliaFork);
        vm.rollFork(5296315); // arbitrary block number used for fork-testing

        address boostPassAddr = 0x0Bd0E39db7F3557Ae9c071209b7B26808157a0Aa;
        boostPass = BoostPass(boostPassAddr);
        vm.label(address(boostPass), "BoostPass");

        owner = boostPass.owner();

        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;
        claimSignerAddr = claimSigner.addr;
       
        // deploy BoostPassVotes contract
        boostPassVotes = new BoostPassVotes(boostPassAddr);
        address boostPassVotesAddr = address(boostPassVotes);
        vm.label(boostPassVotesAddr, "BoostPassVotes");

        minter = vm.createWallet("minter");
        minterAddress = minter.addr;
        delegatee = makeAddr('delegatee');
        vm.deal(minterAddress, 1 ether);
        vm.deal(delegatee, 1 ether);

        // deploy MyGovernor contract
        myGovernor = new MyGovernor(IVotes(boostPassVotesAddr));
        address myGovernorAddr = address(myGovernor);
        vm.label(myGovernorAddr, "MyGovernor");

        assertEq(boostPassVotes.getVotes(minterAddress), 0);

        // upgrade BoostPass contract
        factory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
        vm.startPrank(owner);
        factory.upgrade(boostPassAddr, address(new BoostPass()));

        // manually set claimSignerAddress so that we can mint on this fork
        boostPass.setClaimSignerAddress(claimSignerAddr);
        assertEq(boostPass.claimSignerAddress(), claimSignerAddr);

        vm.warp(block.timestamp + 1);

        // set timestamp and supply
        boostPassVotes.setTimestampAndSupply();

        vm.warp(block.timestamp + 1);

        vm.stopPrank();

        assertEq(boostPassVotes.boostPassSupplyAtCheckpoint(), boostPass.totalSupply());
     
        // use DAI and send it to the governor contract
        address daiAddress = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6; // https://sepolia.etherscan.io/address/0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6
        dai = ERC20(daiAddress);
        deal(address(dai), address(myGovernor), 10 ether);
    }

    function mint_boost_pass() internal {
        bytes memory data = abi.encode(minterAddress, address(0));
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        uint256 mintFee = boostPass.mintFee();
        vm.prank(minterAddress);
        boostPass.mint{value: mintFee}(signature, data);

        assertEq(boostPass.balanceOf(minterAddress), 1);
        assertEq(boostPassVotes.getVotes(minterAddress), 1);
    }

    function test_set_timestamp_and_supply() public {
        assertEq(block.number, 5296315);
        assertEq(boostPassVotes.boostPassSupplyAtCheckpoint(), boostPass.totalSupply()); // account for mint that happens in setUp

        vm.expectRevert(MsgSenderIsNotBoostPassOwner.selector);
        boostPassVotes.setTimestampAndSupply();

        vm.startPrank(owner);
        boostPassVotes.setTimestampAndSupply();
    }

    function test_get_past_votes() public {
        // get votes before upgrade
        uint256 previousTimepoint = boostPassVotes.boostPassCheckpoint() - 1;
        assertEq(boostPassVotes.getPastVotes(minterAddress, previousTimepoint), 0);

        mint_boost_pass();

        vm.warp(block.timestamp + 1);

        // get votes after upgrade (revert)
        uint256 timepoint = boostPassVotes.clock();
        vm.expectRevert(abi.encodeWithSelector(ERC5805FutureLookup.selector, timepoint, timepoint));
        boostPassVotes.getPastTotalSupply(timepoint);
    }

    function test_get_past_total_supply() public {
        uint256 totalSupplyBeforeMint = boostPass.totalSupply();

        mint_boost_pass();

        vm.warp(block.timestamp + 1);

        // get supply before upgrade
        uint256 previousTimepoint = boostPassVotes.boostPassCheckpoint() - 1;
        assertEq(boostPassVotes.getPastTotalSupply(previousTimepoint), totalSupplyBeforeMint);

        // get supply after upgrade (revert)
        uint256 timepoint = boostPassVotes.clock();
        vm.expectRevert(abi.encodeWithSelector(ERC5805FutureLookup.selector, timepoint, timepoint));
        boostPassVotes.getPastTotalSupply(timepoint);

        // get supply after upgrade
        vm.warp(block.timestamp + 1);
        assertEq(boostPassVotes.getPastTotalSupply(timepoint), boostPass.totalSupply());
    }

    function test_after_token_transfer() public {
        vm.expectRevert(MsgSenderIsNotBoostPass.selector);
        boostPassVotes.afterTokenTransfer(address(0), address(0));
    }
  
    function test_proposal_execution() public {
        mint_boost_pass();

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
        vm.prank(minterAddress);
        myGovernor.castVote(proposalId, 1);

        // Execute proposal
        uint256 deadline = myGovernor.proposalDeadline(proposalId);
        vm.warp(deadline + 1);
        uint256 successfulProposalId = myGovernor.execute(targets, values, calldatas, keccak256(abi.encodePacked(description)));

        assertEq(successfulProposalId, proposalId);
        assertEq(dai.balanceOf(owner), 1 ether);
    }

    function test_delegate() public {
        mint_boost_pass();

        // delegate votes
        vm.prank(minterAddress);
        boostPassVotes.delegate(delegatee);
        assertEq(boostPassVotes.delegates(minterAddress), delegatee);
        assertEq(boostPassVotes.getVotes(delegatee), 1);

        // delegatee should mint and increase voting power
        bytes memory data = abi.encode(delegatee, address(0));
        bytes32 msgHash = keccak256(data);
        bytes memory signature = signHash(msgHash, claimSignerPrivateKey);
        uint256 mintFee = boostPass.mintFee();
        vm.prank(delegatee);
        boostPass.mint{value: mintFee}(signature, data);

        // test multiple delegates
        address delegatee2 = makeAddr('delegatee2');
        vm.deal(delegatee2, 1 ether);
        bytes memory data2 = abi.encode(delegatee2, address(0));
        bytes32 msgHash2 = keccak256(data2);
        bytes memory signature2 = signHash(msgHash2, claimSignerPrivateKey);
        vm.startPrank(delegatee2);
        boostPass.mint{value: mintFee}(signature2, data2);
        boostPassVotes.delegate(delegatee);
        vm.stopPrank();

        assertEq(boostPass.balanceOf(delegatee), 1);
        assertEq(boostPassVotes.getVotes(delegatee), 3);
    }

    function test_delegate_by_sig() public {
        mint_boost_pass();

        // Generate a signature for delegation
        bytes32 delegationByteHash = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
        uint256 nonce = boostPassVotes.nonces(minterAddress);
        uint256 expiry = block.timestamp + 1 days;
        bytes32 structHash = keccak256(abi.encode(delegationByteHash, delegatee, nonce, expiry));
        bytes32 digest = ECDSA.toTypedDataHash(boostPassVotes.DOMAIN_SEPARATOR(), structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(minter.privateKey, digest);

        // Delegate votes using signature
        vm.prank(minterAddress);
        boostPassVotes.delegateBySig(delegatee, nonce, expiry, v, r, s);
        assertEq(boostPassVotes.delegates(minterAddress), delegatee);
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
