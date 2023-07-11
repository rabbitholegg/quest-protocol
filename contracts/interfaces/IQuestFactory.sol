// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.18;

interface IQuestFactory {
    error AddressAlreadyMinted();
    error AddressNotSigned();
    error AddressZeroNotAllowed();
    error Erc20QuestAddressNotSet();
    error InvalidHash();
    error OnlyOwnerCanCreate1155Quest();
    error OverMaxAllowedToMint();
    error QuestEnded();
    error QuestFeeTooHigh();
    error QuestIdUsed();
    error QuestNotQueued();
    error QuestNotStarted();
    error QuestTypeInvalid();
    error RewardNotAllowed();
    error ZeroAddressNotAllowed();
    error MsgValueLessThanQuestNFTFee();
    error Deprecated();

    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint endTime,
        uint startTime,
        uint totalParticipants,
        uint rewardAmountOrTokenId
    );
     event Quest1155Created(
        address indexed creator,
        address indexed contractAddress,
        string questId,
        string contractType,
        address rewardTokenAddress,
        uint endTime,
        uint startTime,
        uint totalParticipants,
        uint rewardAmountOrTokenId
    );
    event ReceiptMinted(address indexed recipient, address indexed questAddress, uint indexed tokenId, string questId);
    event QuestNFTMinted(address indexed recipient, address indexed questAddress, uint indexed tokenId, string questId);
    event MintFeeSet(uint percent);
    event ExtraMintFeeReturned(address indexed recipient, uint amount);
    event NftQuestFeeSet(uint fee);
    event QuestNFTCreated(address indexed newQuestNFT, address questCreator, string collectionName);
    event QuestClaimed(address indexed recipient, address indexed questAddress, string questId, address rewardToken, uint rewardAmountInWei);
    event Quest1155Claimed(address indexed recipient, address indexed questAddress, string questId, address rewardToken, uint tokenId);

    function questInfo(string memory questId_) external view returns (address, uint, uint);
}
