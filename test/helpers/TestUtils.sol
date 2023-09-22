// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract TestUtils {
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


  // const maxTotalRewards = calculateTotalRewards
  // const maxProtocolReward = calculateTotalFees
  // const transferAmount = calculateTotalRewardsPlusFee
}
