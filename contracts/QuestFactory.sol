// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Erc20Quest} from './Erc20Quest.sol';
import {Erc1155Quest} from './Erc1155Quest.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';

contract QuestFactory is Initializable, OwnableUpgradeable {
    error QuestIdUsed();
    error OverMaxAllowedToMint();
    error AddressNotSigned();
    error AddressAlreadyMinted();
    error InvalidHash();

    event QuestCreated(address indexed creator, address indexed contractAddress, string contractType);

    // storage vars. Insert new vars at the end to keep the storage layout the same.
    address public claimSignerAddress;
    mapping(string => address) public questAddressForQuestId;
    mapping(string => uint256) public totalAmountForQuestId;
    mapping(string => uint256) public amountMintedForQuestId;
    RabbitHoleReceipt public rabbitholeReceiptContract;
    mapping(string => mapping(address => bool)) public addressMintedForQuestId;

    // always be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address claimSignerAddress_, address rabbitholeReceiptContract_) public initializer {
        __Ownable_init();
        claimSignerAddress = claimSignerAddress_;
        rabbitholeReceiptContract = RabbitHoleReceipt(rabbitholeReceiptContract_);
    }

    function createQuest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalAmount_,
        string memory allowList_,
        uint256 rewardAmountOrTokenId_,
        string memory contractType_,
        string memory questId_,
        address receiptContractAddress_
    ) public onlyOwner returns (address) {
        if (questAddressForQuestId[questId_] != address(0)) revert QuestIdUsed();

        if (keccak256(abi.encodePacked(contractType_)) == keccak256(abi.encodePacked('erc20'))) {
            Erc20Quest newQuest = new Erc20Quest(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalAmount_,
                allowList_,
                rewardAmountOrTokenId_,
                questId_,
                receiptContractAddress_
            );
            newQuest.transferOwnership(msg.sender);

            emit QuestCreated(msg.sender, address(newQuest), contractType_);
            questAddressForQuestId[questId_] = address(newQuest);
            totalAmountForQuestId[questId_] = totalAmount_;
            return address(newQuest);
        }

        if (keccak256(abi.encodePacked(contractType_)) == keccak256(abi.encodePacked('erc1155'))) {
            Erc1155Quest newQuest = new Erc1155Quest(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalAmount_,
                allowList_,
                rewardAmountOrTokenId_,
                questId_,
                receiptContractAddress_
            );
            newQuest.transferOwnership(msg.sender);

            emit QuestCreated(msg.sender, address(newQuest), contractType_);
            questAddressForQuestId[questId_] = address(newQuest);
            totalAmountForQuestId[questId_] = totalAmount_;
            return address(newQuest);
        }

        return address(0);
    }

    function setClaimSignerAddress(address claimSignerAddress_) public onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    function setRabbitHoleReceiptContract(address rabbitholeReceiptContract_) public onlyOwner {
        rabbitholeReceiptContract = RabbitHoleReceipt(rabbitholeReceiptContract_);
    }

    function getQuestAddress(string memory questId_) external view returns (address) {
        return questAddressForQuestId[questId_];
    }

    function recoverSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', hash));
        return ECDSAUpgradeable.recover(messageDigest, signature);
    }

    // need to set this contract as Minter on the receipt contract.
    function mintReceipt(uint amount_, string memory questId_, bytes32 hash_, bytes memory signature_) public {
        if (amountMintedForQuestId[questId_] + amount_ > totalAmountForQuestId[questId_]) revert OverMaxAllowedToMint();
        if (addressMintedForQuestId[questId_][msg.sender] == true) revert AddressAlreadyMinted();
        if (keccak256(abi.encodePacked(msg.sender, questId_)) != hash_) revert InvalidHash();
        if (recoverSigner(hash_, signature_) != claimSignerAddress) revert AddressNotSigned();

        amountMintedForQuestId[questId_] += amount_;
        addressMintedForQuestId[questId_][msg.sender] = true;
        rabbitholeReceiptContract.mint(msg.sender, amount_, questId_);
    }
}
