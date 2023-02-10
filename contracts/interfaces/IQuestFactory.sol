// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.16;

interface IQuestFactory {
    error QuestIdUsed();
    error OverMaxAllowedToMint();
    error AddressNotSigned();
    error AddressAlreadyMinted();
    error InvalidHash();
    error OnlyOwnerCanCreate1155Quest();
    error RewardNotAllowed();
    error QuestTypeInvalid();
    error AddressZeroNotAllowed();
    error QuestFeeTooHigh();
    error QuestNotStarted();
    error QuestEnded();

    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint256 endTime,
        uint256 startTime,
        uint256 totalParticipants,
        uint256 rewardAmountOrTokenId
    );
    event ReceiptMinted(address indexed recipient, address indexed questAddress, uint indexed tokenId, string questId);

    function questInfo(string memory questId_) external view returns (address, uint, uint);
}
