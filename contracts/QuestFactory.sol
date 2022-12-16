// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Erc20Quest} from './Erc20Quest.sol';
import {Erc1155Quest} from './Erc1155Quest.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

contract QuestFactory is Initializable, OwnableUpgradeable {
    error QuestIdUsed();
    error OverMaxAllowedToMint();

    address public claimSignerAddress;
    address public minterAddress;
    RabbitHoleReceipt public rabbitholeReceiptContract;

    // TODO: add a numerical questId (OZ's counter)
    mapping(string => address) public questAddressForQuestId;
    mapping(string => uint256) public totalAmountForQuestId;
    mapping(string => uint256) public amountMintedForQuestId;

    // Todo create data structure of all quests

    event QuestCreated(address indexed creator, address indexed contractAddress, string contractType);

    // always be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    modifier onlyMinter() {
        msg.sender == minterAddress;
        _;
    }

    function initialize(address claimSignerAddress_, address rabbitholeReceiptContract_, address minterAddress_) public initializer {
        __Ownable_init();
        claimSignerAddress = claimSignerAddress_;
        rabbitholeReceiptContract = RabbitHoleReceipt(rabbitholeReceiptContract_);
        minterAddress = minterAddress_;
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
            Erc20Quest newQuest = new Erc20Quest();
            newQuest.initialize(
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
            Erc1155Quest newQuest = new Erc1155Quest();
            newQuest.initialize(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalAmount_,
                allowList_,
                rewardAmountOrTokenId_,
                questId_,
                receiptContractAddress_,
                claimSignerAddress
            );
            newQuest.transferOwnership(msg.sender);

            emit QuestCreated(msg.sender, address(newQuest), contractType_);
            questAddressForQuestId[questId_] = address(newQuest);
            return address(newQuest);
        }

        return address(0);
    }

    function setClaimSignerAddress(address claimSignerAddress_) public onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    function getQuestAddress(string memory questId_) external view returns (address) {
        return questAddressForQuestId[questId_];
    }

    // need to set this contract as Minter on the receipt contract.
    function mintReceipt(unit amount_, string memory questId_) onlyMinter public {
        if (totalAmountForQuestId[questId_] - amountMintedForQuestId[questId_] - amount_ < 0) revert OverMaxAllowedToMint();
        amountMintedForQuestId[questId_] += amount_;
        rabbitholeReceiptContract.mint(msg.sender, amount_, questId_);
    }

}
