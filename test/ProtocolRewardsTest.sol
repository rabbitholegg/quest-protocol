// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/ProtocolRewards.sol";

contract ProtocolRewardsTest is Test {
    uint256 internal constant ETH_SUPPLY = 120_200_000 ether;

    ProtocolRewards internal protocolRewards;

    address internal collector;
    address internal collector2;
    address internal creator;
    address internal owner;

    function setUp() public virtual {
        collector = makeAddr("collector");
        collector2 = makeAddr("collector2");
        creator = makeAddr("creator");
        owner = makeAddr("owner");

        vm.prank(owner);
        protocolRewards = new ProtocolRewards();
        vm.label(address(protocolRewards), "protocolRewards");

        vm.deal(collector, 40 ether);
        vm.deal(creator, 20 ether);
        vm.deal(owner, 10 ether);

        vm.prank(collector);
        protocolRewards.deposit{value: 10 ether}(creator, "", "");
        (bool success,) = address(protocolRewards).call{value: 20 ether}("");
        require(success, "deposit failed");
    }

    // increase balance tests
        function testExcessSupply() public {
        assertEq(protocolRewards.totalBalance(), 10 ether);
        assertEq(protocolRewards.excessSupply(), 20 ether);
    }

    function testIncreaseBalance() public {
        vm.prank(owner);
        protocolRewards.increaseBalance(collector, 5 ether);

        assertEq(protocolRewards.balanceOf(collector), 5 ether);
        assertEq(protocolRewards.totalBalance(), 15 ether);
        assertEq(protocolRewards.excessSupply(), 15 ether);
    }

    function testIncreaseBalance_with_error_INVALID_AMOUNT() public {
        vm.expectRevert(abi.encodeWithSignature("INVALID_AMOUNT()"));

        vm.prank(owner);
        protocolRewards.increaseBalance(collector, 100 ether);
    }

    function testIncreaseBalanceBatch() public {
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector2;

        uint256[] memory values = new uint256[](2);
        values[0] = uint256(5 ether);
        values[1] = uint256(3 ether);

        vm.prank(owner);
        protocolRewards.increaseBalanceBatch(addresses, values);

        assertEq(protocolRewards.balanceOf(collector), 5 ether);
        assertEq(protocolRewards.balanceOf(collector2), 3 ether);
        assertEq(protocolRewards.totalBalance(), 18 ether);
        assertEq(protocolRewards.excessSupply(), 12 ether);
    }


    function testIncreaseBalanceBatch_with_error_INVALID_AMOUNT() public {
        vm.expectRevert(abi.encodeWithSignature("INVALID_AMOUNT()"));

        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector2;

        uint256[] memory values = new uint256[](2);
        values[0] = uint256(5 ether);
        values[1] = uint256(300 ether);

        vm.prank(owner);
        protocolRewards.increaseBalanceBatch(addresses, values);
    }

    // withdraw tests
    function getDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ProtocolRewards")),
                keccak256(bytes("1")),
                block.chainid,
                address(protocolRewards)
            )
        );
    }

    function testWithdraw() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.prank(creator);
        protocolRewards.withdraw(creator, creatorRewardsBalance);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function testWithdrawFullBalance() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.prank(creator);
        protocolRewards.withdraw(creator, 0);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function testRevert_InvalidWithdrawToAddress() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        vm.prank(creator);
        protocolRewards.withdraw(address(0), creatorRewardsBalance);
    }

    function testRevert_WithdrawInvalidAmount() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("INVALID_WITHDRAW()"));
        vm.prank(creator);
        protocolRewards.withdraw(creator, creatorRewardsBalance + 1);
    }

    function testWithdrawFor() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        protocolRewards.withdrawFor(creator, creatorRewardsBalance);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function testWithdrawForFullBalance() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        protocolRewards.withdrawFor(creator, 0);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function testRevert_WithdrawForInvalidAmount() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("INVALID_WITHDRAW()"));
        protocolRewards.withdrawFor(creator, creatorRewardsBalance + 1);
    }

    function testRevert_WithdrawForInvalidToAddress() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        protocolRewards.withdrawFor(address(0), creatorRewardsBalance);
    }

    function testWithdrawWithSig() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, creator, creatorRewardsBalance, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        protocolRewards.withdrawWithSig(creator, creator, creatorRewardsBalance, deadline, v, r, s);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function testWithdrawWithSigFullBalance() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash =
            keccak256(abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, creator, 0, nonce, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        protocolRewards.withdrawWithSig(creator, creator, 0, deadline, v, r, s);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function testRevert_SigExpired() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);
        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, creator, creatorRewardsBalance, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        vm.warp(deadline + 1);

        vm.expectRevert(abi.encodeWithSignature("SIGNATURE_DEADLINE_EXPIRED()"));
        protocolRewards.withdrawWithSig(creator, creator, creatorRewardsBalance, deadline, v, r, s);
    }

    function testRevert_InvalidWithdrawWithSigToAddress() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, address(0), creatorRewardsBalance, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        protocolRewards.withdrawWithSig(creator, address(0), creatorRewardsBalance, deadline, v, r, s);
    }

    function testRevert_InvalidNonce() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);
        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator) + 1;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, creator, creatorRewardsBalance, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        protocolRewards.withdrawWithSig(creator, creator, creatorRewardsBalance, deadline, v, r, s);
    }

    function testRevert_InvalidSigner() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);
        (address notCreator, uint256 notCreatorPrivateKey) = makeAddrAndKey("notCreator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, notCreator, creatorRewardsBalance, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(notCreatorPrivateKey, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        protocolRewards.withdrawWithSig(creator, notCreator, creatorRewardsBalance, deadline, v, r, s);
    }

    function testRevert_InvalidWithdrawAmount() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);
        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(
                protocolRewards.WITHDRAW_TYPEHASH(), creator, creator, creatorRewardsBalance + 1, nonce, deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        vm.expectRevert(abi.encodeWithSignature("INVALID_WITHDRAW()"));
        protocolRewards.withdrawWithSig(creator, creator, creatorRewardsBalance + 1, deadline, v, r, s);
    }

    function testRevert_InvalidReplay() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);
        (, uint256 creatorPrivateKey) = makeAddrAndKey("creator");

        uint256 nonce = protocolRewards.nonces(creator);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 withdrawHash = keccak256(
            abi.encode(protocolRewards.WITHDRAW_TYPEHASH(), creator, creator, creatorRewardsBalance, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", getDomainSeparator(), withdrawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        protocolRewards.withdrawWithSig(creator, creator, creatorRewardsBalance, deadline, v, r, s);

        vm.expectRevert(abi.encodeWithSignature("INVALID_SIGNATURE()"));
        protocolRewards.withdrawWithSig(creator, creator, creatorRewardsBalance, deadline, v, r, s);
    }
}
