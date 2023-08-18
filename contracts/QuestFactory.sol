// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

// Inherits
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "./OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// Implements
import {IQuestFactory} from "./interfaces/IQuestFactory.sol";
// Leverages
import {ECDSA} from "solady/src/utils/ECDSA.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
// References
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IQuestOwnable} from "./interfaces/IQuestOwnable.sol";
import {IQuest1155Ownable} from "./interfaces/IQuest1155Ownable.sol";
import {IQuestTerminalKeyERC721} from "./interfaces/IQuestTerminalKeyERC721.sol";

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create quests and handle claims
// solhint-disable-next-line max-states-count
contract QuestFactory is Initializable, OwnableUpgradeable, AccessControlUpgradeable, IQuestFactory {
    using SafeTransferLib for address;
    using LibClone for address;
    using LibString for string;
    using LibString for uint256;

    // storage vars. Insert new vars at the end to keep the storage layout the same.
    address public claimSignerAddress;
    address public protocolFeeRecipient;
    address public erc20QuestAddress;
    address public erc1155QuestAddress;
    mapping(string => Quest) public quests;
    address public rabbitHoleReceiptContract;
    address public rabbitHoleTicketsContract;
    mapping(address => bool) public rewardAllowlist;
    uint16 public questFee;
    uint256 public mintFee;
    address public mintFeeRecipient;
    uint256 private locked;
    IQuestTerminalKeyERC721 private questTerminalKeyContract;
    uint256 public nftQuestFee;
    address public questNFTAddress;
    mapping(address => address[]) public ownerCollections;
    mapping(address => NftQuestFees) public nftQuestFeeList;
    uint16 public referralFee;
    address public sablierV2LockupLinearAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() initializer {}

    function initialize(
        address claimSignerAddress_,
        address protocolFeeRecipient_,
        address erc20QuestAddress_,
        address payable erc1155QuestAddress_,
        address ownerAddress_,
        address questTerminalKeyAddress_,
        address sablierV2LockupLinearAddress_,
        uint256 nftQuestFee_,
        uint16 referralFee_
    ) external initializer {
        __Ownable_init(ownerAddress_);
        __AccessControl_init();
        questFee = 2000; // in BIPS
        locked = 1;
        claimSignerAddress = claimSignerAddress_;
        protocolFeeRecipient = protocolFeeRecipient_;
        erc20QuestAddress = erc20QuestAddress_;
        erc1155QuestAddress = erc1155QuestAddress_;
        questTerminalKeyContract = IQuestTerminalKeyERC721(questTerminalKeyAddress_);
        sablierV2LockupLinearAddress = sablierV2LockupLinearAddress_;
        nftQuestFee = nftQuestFee_;
        referralFee = referralFee_;
    }

    /// @dev ReentrancyGuard modifier from solmate, copied here because it was added after storage layout was finalized on first deploy
    /// @dev from https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol
    modifier nonReentrant() virtual {
        if (locked == 0) locked = 1;
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    modifier claimChecks(string memory questId_, bytes32 hash_, bytes memory signature_, address ref_) {
        Quest storage currentQuest = quests[questId_];
        bytes32 encodedHash;
        if (ref_ == address(0)) {
            encodedHash = keccak256(abi.encodePacked(msg.sender, questId_));
        } else {
            encodedHash = keccak256(abi.encodePacked(msg.sender, questId_, ref_));
        }

        if (currentQuest.numberMinted + 1 > currentQuest.totalParticipants) revert OverMaxAllowedToMint();
        if (currentQuest.addressMinted[msg.sender]) revert AddressAlreadyMinted();
        if (encodedHash != hash_) revert InvalidHash();
        if (recoverSigner(hash_, signature_) != claimSignerAddress) revert AddressNotSigned();
        _;
    }

    modifier sufficientMintFee() {
        if (msg.value < mintFee) revert InvalidMintFee();
        _;
    }

    modifier checkQuest(string memory questId_, address rewardTokenAddress_) {
        Quest storage currentQuest = quests[questId_];
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();
        if (!rewardAllowlist[rewardTokenAddress_]) revert RewardNotAllowed();
        if (erc20QuestAddress == address(0)) revert Erc20QuestAddressNotSet();
        _;
    }

    modifier nonZeroAddress(address address_) {
        if (address_ == address(0)) revert ZeroAddressNotAllowed();
        _;
    }

    function createERC20QuestInternal(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionSpec_,
        uint40 durationTotal_
    ) internal returns (address) {
        Quest storage currentQuest = quests[questId_];
        address newQuest = erc20QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_)));

        if (bytes(actionSpec_).length > 0) {
            emit QuestCreatedWithAction(
                msg.sender,
                address(newQuest),
                questId_,
                "erc20",
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_,
                actionSpec_
                );
        } else {
            emit QuestCreated(
                msg.sender,
                address(newQuest),
                questId_,
                "erc20",
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_
                );
        }
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = totalParticipants_;
        if (durationTotal_ > 0) {
            currentQuest.durationTotal = durationTotal_;
            currentQuest.questType = "erc20Stream";
        } else {
            currentQuest.questType = "erc20";
        }

        IQuestOwnable(newQuest).initialize(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            questFee,
            protocolFeeRecipient,
            durationTotal_,
            sablierV2LockupLinearAddress
        );

        return newQuest;
    }

    /// @dev Transfer the total transfer amount to the quest contract
    /// @dev Contract must be approved to transfer first
    /// @param newQuest_ The address of the new quest
    /// @param rewardTokenAddress_ The contract address of the reward token
    function transferTokensAndOwnership(address newQuest_, address rewardTokenAddress_) internal {
        address sender = msg.sender;
        IQuestOwnable questContract = IQuestOwnable(newQuest_);
        rewardTokenAddress_.safeTransferFrom(sender, newQuest_, questContract.totalTransferAmount());
        questContract.transferOwnership(sender);
    }

    /// @dev Create a sablier stream reward quest and start it at the same time.
    /// @notice The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionSpec_ The JSON action spec for the quest
    /// @param durationTotal_ The duration of the sablier stream
    /// @return address the quest contract address
    function createERC20StreamQuest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionSpec_,
        uint40 durationTotal_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createERC20QuestInternal(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            actionSpec_,
            durationTotal_
        );
        transferTokensAndOwnership(newQuest, rewardTokenAddress_);
        return newQuest;
    }

    /// @dev Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionSpec_ The JSON action spec for the quest
    /// @return address the quest contract address
    function createQuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionSpec_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createERC20QuestInternal(
            rewardTokenAddress_, endTime_, startTime_, totalParticipants_, rewardAmount_, questId_, actionSpec_, 0
        );
        transferTokensAndOwnership(newQuest, rewardTokenAddress_);
        return newQuest;
    }

    /// @dev Create an erc1155 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param tokenId_ The reward token id of the erc1155 at rewardTokenAddress_
    /// @param questId_ The id of the quest
    /// @return address the quest contract address
    function create1155QuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 tokenId_,
        string memory questId_,
        string memory actionSpec_
    ) external payable nonReentrant returns (address) {
        Quest storage currentQuest = quests[questId_];

        if (msg.value < totalQuestNFTFee(totalParticipants_)) revert MsgValueLessThanQuestNFTFee();
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();

        address payable newQuest =
            payable(erc1155QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_))));
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = totalParticipants_;
        currentQuest.questAddress.safeTransferETH(msg.value);
        currentQuest.questType = "erc1155";
        IQuest1155Ownable questContract = IQuest1155Ownable(newQuest);

        questContract.initialize(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            tokenId_,
            getNftQuestFee(msg.sender),
            protocolFeeRecipient
        );

        IERC1155(rewardTokenAddress_).safeTransferFrom(msg.sender, newQuest, tokenId_, totalParticipants_, "0x00");
        questContract.queue();
        questContract.transferOwnership(msg.sender);

        if (bytes(actionSpec_).length > 0) {
            emit QuestCreatedWithAction(
                msg.sender,
                address(newQuest),
                questId_,
                "erc1155",
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_,
                actionSpec_
                );
        } else {
            emit QuestCreated(
                msg.sender,
                address(newQuest),
                questId_,
                "erc1155",
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_
                );
        }

        return newQuest;
    }

    function totalQuestNFTFee(uint256 totalParticipants_) public view returns (uint256) {
        return totalParticipants_ * getNftQuestFee(msg.sender);
    }

    function getNftQuestFee(address address_) public view returns (uint256) {
        return nftQuestFeeList[address_].exists ? nftQuestFeeList[address_].fee : nftQuestFee;
    }

    /// @dev set erc20QuestAddress
    /// @param erc20QuestAddress_ The address of the erc20 quest
    function setErc20QuestAddress(address erc20QuestAddress_) public onlyOwner {
        erc20QuestAddress = erc20QuestAddress_;
    }

    /// @dev set erc1155QuestAddress
    /// @param erc1155QuestAddress_ The address of the erc1155 quest
    function setErc1155QuestAddress(address erc1155QuestAddress_) public onlyOwner {
        erc1155QuestAddress = erc1155QuestAddress_;
    }

    /// @dev set the claim signer address
    /// @param claimSignerAddress_ The address of the claim signer
    function setClaimSignerAddress(address claimSignerAddress_) public onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    /// @dev set the protocol fee recipient
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient
    function setProtocolFeeRecipient(address protocolFeeRecipient_) public onlyOwner {
        if (protocolFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    /// @dev set the mintFeeRecipient
    /// @param mintFeeRecipient_ The address of the mint fee recipient
    function setMintFeeRecipient(address mintFeeRecipient_) public onlyOwner {
        if (mintFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        mintFeeRecipient = mintFeeRecipient_;
    }

    /// @dev get the mintFeeRecipient return the protocol fee recipient if the mint fee recipient is not set
    /// @return address the mint fee recipient
    function getMintFeeRecipient() public view returns (address) {
        if (mintFeeRecipient == address(0)) {
            return protocolFeeRecipient;
        }
        return mintFeeRecipient;
    }

    /// @dev set the nftQuestFee
    /// @param nftQuestFee_ The value of the nftQuestFee
    function setNftQuestFee(uint256 nftQuestFee_) external onlyOwner {
        nftQuestFee = nftQuestFee_;
        emit NftQuestFeeSet(nftQuestFee_);
    }

    /// @dev set the referral fee
    /// @param referralFee_ The value of the referralFee
    function setReferralFee(uint16 referralFee_) external onlyOwner {
        if (referralFee_ > 10_000) revert ReferralFeeTooHigh();
        referralFee = referralFee_;
        emit ReferralFeeSet(referralFee_);
    }

    /// @dev set questTerminalKeyContract address
    /// @param questTerminalKeyContract_ The address of the questTerminalKeyContract
    function setQuestTerminalKeyContract(address questTerminalKeyContract_) external onlyOwner {
        questTerminalKeyContract = IQuestTerminalKeyERC721(questTerminalKeyContract_);
    }

    /// @dev set or remave a contract address to be used as a reward
    /// @param rewardAddress_ The contract address to set
    /// @param allowed_ Whether the contract address is allowed or not
    function setRewardAllowlistAddress(address rewardAddress_, bool allowed_) public onlyOwner {
        rewardAllowlist[rewardAddress_] = allowed_;
    }

    /// @dev set the quest fee
    /// @notice the quest fee should be in Basis Point units
    /// @param questFee_ The quest fee value
    function setQuestFee(uint16 questFee_) public onlyOwner {
        if (questFee_ > 10_000) revert QuestFeeTooHigh();
        questFee = questFee_;
    }

    /// @dev set the mint fee
    /// @notice the mint fee in ether
    /// @param mintFee_ The mint fee value
    function setMintFee(uint256 mintFee_) public onlyOwner {
        mintFee = mintFee_;
        emit MintFeeSet(mintFee_);
    }

    /// @notice Right now this is a misnomer - it tracks total claims vs receipts minted
    /// @dev return the number of quest claims submitted
    /// @param questId_ The id of the quest
    /// @return uint Total quests claimed
    function getNumberMinted(string memory questId_) external view returns (uint256) {
        return quests[questId_].numberMinted;
    }

    /// @dev return extended quest data for a questId
    /// @param questId_ The id of the quest
    function questData(string memory questId_) external view returns (QuestData memory) {
        Quest storage thisQuest = quests[questId_];
        IQuestOwnable questContract = IQuestOwnable(thisQuest.questAddress);
        uint256 rewardAmountOrTokenId;
        uint16 erc20QuestFee;

        if (thisQuest.questType.eq("erc1155")) {
            rewardAmountOrTokenId = IQuest1155Ownable(thisQuest.questAddress).tokenId();
        } else {
            rewardAmountOrTokenId = questContract.rewardAmountInWei();
            erc20QuestFee = questContract.questFee();
        }

        QuestData memory data = QuestData(
            thisQuest.questAddress,
            questContract.rewardToken(),
            questContract.queued(),
            erc20QuestFee,
            questContract.startTime(),
            questContract.endTime(),
            questContract.totalParticipants(),
            thisQuest.numberMinted,
            questContract.redeemedTokens(),
            rewardAmountOrTokenId,
            questContract.hasWithdrawn(),
            thisQuest.questType,
            thisQuest.durationTotal
        );

        return data;
    }

    /// @dev return data in the quest struct for a questId
    /// @param questId_ The id of the quest
    function questInfo(string memory questId_) external view returns (address, uint256, uint256) {
        Quest storage currentQuest = quests[questId_];
        return (currentQuest.questAddress, currentQuest.totalParticipants, currentQuest.numberMinted);
    }

    /// @notice This function name is a bit of a misnomer - gets whether an address has claimed a quest yet.
    /// @dev return status of whether an address has claimed a quest
    /// @param questId_ The id of the quest
    /// @param address_ The address to check
    /// @return claimed status
    function getAddressMinted(string memory questId_, address address_) external view returns (bool) {
        return quests[questId_].addressMinted[address_];
    }

    /// @dev recover the signer from a hash and signature
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function recoverSigner(bytes32 hash_, bytes memory signature_) public view returns (address) {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash_), signature_);
    }

    /// @dev universal claim function for all quest types
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    /// @param ref_ The referral address
    function claim(string memory questId_, bytes32 hash_, bytes memory signature_, address ref_) external payable {
        if (quests[questId_].questType.eq("erc20")) {
            claimRewardsRef(questId_, hash_, signature_, ref_);
        } else if (quests[questId_].questType.eq("erc1155")) {
            claim1155RewardsRef(questId_, hash_, signature_, ref_);
        } else {
            revert QuestTypeNotSupported();
        }
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claimRewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable {
        claimRewardsRef(questId_, hash_, signature_, address(0));
    }

    /// @dev claim rewards with a referral address
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    /// @param ref_ The referral address
    function claimRewardsRef(
        string memory questId_,
        bytes32 hash_,
        bytes memory signature_,
        address ref_
    ) private nonReentrant sufficientMintFee claimChecks(questId_, hash_, signature_, ref_) {
        Quest storage currentQuest = quests[questId_];
        IQuestOwnable questContract_ = IQuestOwnable(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if (mintFee > 0) processMintFee(ref_);

        emit QuestClaimed(
            msg.sender,
            currentQuest.questAddress,
            questId_,
            questContract_.rewardToken(),
            questContract_.rewardAmountInWei()
            );

        if (ref_ != address(0)) {
            emit QuestClaimedReferred(
                msg.sender,
                currentQuest.questAddress,
                questId_,
                questContract_.rewardToken(),
                questContract_.rewardAmountInWei(),
                ref_,
                referralFee,
                mintFee
                );
        }
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claim1155Rewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable {
        claim1155RewardsRef(questId_, hash_, signature_, address(0));
    }

    /// @dev claim rewards for a quest with a referral address
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claim1155RewardsRef(
        string memory questId_,
        bytes32 hash_,
        bytes memory signature_,
        address ref_
    ) private nonReentrant sufficientMintFee claimChecks(questId_, hash_, signature_, ref_) {
        Quest storage currentQuest = quests[questId_];
        IQuest1155Ownable questContract_ = IQuest1155Ownable(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if (mintFee > 0) processMintFee(ref_);

        emit Quest1155Claimed(
            msg.sender, currentQuest.questAddress, questId_, questContract_.rewardToken(), questContract_.tokenId()
            );

        if (ref_ != address(0)) {
            emit QuestClaimedReferred(
                msg.sender,
                currentQuest.questAddress,
                questId_,
                questContract_.rewardToken(),
                questContract_.tokenId(),
                ref_,
                referralFee,
                mintFee
                );
        }
    }

    function processMintFee(address ref_) private {
        returnChange();
        if (ref_ == address(0)) {
            getMintFeeRecipient().safeTransferETH(mintFee);
            return;
        }
        uint256 referralAmount = (mintFee * referralFee) / 10_000;
        ref_.safeTransferETH(referralAmount);
        getMintFeeRecipient().safeTransferETH(mintFee - referralAmount);
    }

    function returnChange() private {
        uint256 change = msg.value - mintFee;
        if (change > 0) {
            // Refund any excess payment
            msg.sender.safeTransferETH(change);
            emit ExtraMintFeeReturned(msg.sender, change);
        }
    }

    function setNftQuestFeeList(address[] calldata toAddAddresses_, uint256[] calldata fees_) external onlyOwner {
        for (uint256 i = 0; i < toAddAddresses_.length; i++) {
            nftQuestFeeList[toAddAddresses_[i]] = NftQuestFees(fees_[i], true);
        }
        emit NftQuestFeeListSet(toAddAddresses_, fees_);
    }

    /// @dev set sablierV2LockupLinearAddress
    /// @param sablierV2LockupLinearAddress_ The address of the sablierV2LockupLinear contract
    function setSablierV2LockupLinearAddress(address sablierV2LockupLinearAddress_) external onlyOwner {
        sablierV2LockupLinearAddress = sablierV2LockupLinearAddress_;
        emit SablierV2LockupLinearAddressSet(sablierV2LockupLinearAddress_);
    }

    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}
