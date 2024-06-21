// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "forge-std/Test.sol";

contract TestUtils is Test {
    function calculateTotalRewardsPlusFee(
        uint256 totalParticipants,
        uint256 rewardAmount,
        uint16 questFee,
        uint16 referralFee
    ) internal pure returns (uint256) {
        return calculateTotalRewards(totalParticipants, rewardAmount)
            + calculateTotalProtocolFees(totalParticipants, rewardAmount, questFee)
            + calculateTotalReferralFees(totalParticipants, rewardAmount, referralFee);
    }

    function calculateTotalRewards(uint256 totalParticipants, uint256 rewardAmount) internal pure returns (uint256) {
        return totalParticipants * rewardAmount;
    }

    function calculateTotalProtocolFees(
        uint256 totalParticipants,
        uint256 rewardAmount,
        uint16 questFee
    ) internal pure returns (uint256) {
        return (totalParticipants * rewardAmount * questFee) / 10_000;
    }

    function calculateTotalReferralFees(
        uint256 totalParticipants,
        uint256 rewardAmount,
        uint16 referralFee
    ) internal pure returns (uint256) {
        return (totalParticipants * rewardAmount * referralFee) / 10_000;
    }

    function signHash(bytes32 msgHash, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function getSplitSignature(uint256 privateKey, bytes32 msgHash) internal pure returns (bytes memory _signature, bytes32 _r, bytes32 _vs) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);

        uint8 normalizedV = v - 27;
        bytes32 shiftedV = bytes32(uint256(normalizedV) << 255);

        _signature = abi.encodePacked(r, s, v);
        _r = r;
        _vs = shiftedV | s;
    }
}
