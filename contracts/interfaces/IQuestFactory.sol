// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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

    event QuestCreated(address indexed creator, address indexed contractAddress, string contractType);
}
