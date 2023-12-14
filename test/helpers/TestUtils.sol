// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "forge-std/Test.sol";

contract TestUtils is Test {
    function calculateTotalRewardsPlusFee(
        uint256 totalParticipants,
        uint256 rewardAmount,
        uint16 questFee
    ) internal pure returns (uint256) {
        return calculateTotalRewards(totalParticipants, rewardAmount)
            + calculateTotalFees(totalParticipants, rewardAmount, questFee);
    }

    function calculateTotalRewards(uint256 totalParticipants, uint256 rewardAmount) internal pure returns (uint256) {
        return totalParticipants * rewardAmount;
    }

    function calculateTotalFees(
        uint256 totalParticipants,
        uint256 rewardAmount,
        uint16 questFee
    ) internal pure returns (uint256) {
        return (totalParticipants * rewardAmount * questFee) / 10_000;
    }

    function signHash(bytes32 msgHash, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 digest = ECDSA.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
