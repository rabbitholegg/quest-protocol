// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Inherits
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {LegacyStorage} from "./libraries/LegacyStorage.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
// Implements
import {IQuestFactory} from "./interfaces/IQuestFactory.sol";
// Leverages
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibZip} from "solady/utils/LibZip.sol";
// References
import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {IQuestOwnable} from "./interfaces/IQuestOwnable.sol";
import {IQuest1155Ownable} from "./interfaces/IQuest1155Ownable.sol";

// todo turn into interface
import {SoulBound20} from "./SoulBound20.sol";

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create quests and handle claims
// solhint-disable-next-line max-states-count
/// @custom:oz-upgrades-from QuestFactoryV0
contract QuestFactory is Initializable, LegacyStorage, OwnableRoles, IQuestFactory {
    /*//////////////////////////////////////////////////////////////
                                 USING
    //////////////////////////////////////////////////////////////*/
    using SafeTransferLib for address;
    using LibClone for address;
    using LibString for string;
    using LibString for uint256;
    using LibString for address;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public claimSignerAddress;
    address public protocolFeeRecipient;
    address public erc20QuestAddress;
    address public erc1155QuestAddress;
    mapping(string => Quest) public quests;
    address public rabbitHoleReceiptContract; // not used
    address public rabbitHoleTicketsContract; // not used
    mapping(address => bool) public rewardAllowlist;
    uint16 public questFee;
    uint256 public mintFee;
    /// @custom:oz-renamed-from mintFeeRecipient
    address public defaultMintFeeRecipient;
    uint256 private locked;
    /// @custom:oz-renamed-from questTerminalKeyContract
    address public defaultReferralFeeRecipient;
    uint256 public nftQuestFee;
    address public soulbound20Address;
    mapping(address => address[]) public ownerPointAddresses;
    mapping(address => NftQuestFees) public nftQuestFeeList;
    uint16 public referralFee;
    address public sablierV2LockupLinearAddress;
    mapping(address => address) public mintFeeRecipientList;
    mapping(address => uint256) public soulbound2OState;
    // insert new vars here at the end to keep the storage layout the same

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() initializer {}

    function initialize(
        address claimSignerAddress_,
        address protocolFeeRecipient_,
        address erc20QuestAddress_,
        address payable erc1155QuestAddress_,
        address ownerAddress_,
        address defaultReferralFeeRecipientAddress_,
        address sablierV2LockupLinearAddress_,
        uint256 nftQuestFee_,
        uint16 referralFee_,
        uint256 mintFee_
    ) external initializer {
        _initializeOwner(ownerAddress_);
        questFee = 2000; // in BIPS
        locked = 1;
        claimSignerAddress = claimSignerAddress_;
        protocolFeeRecipient = protocolFeeRecipient_;
        erc20QuestAddress = erc20QuestAddress_;
        erc1155QuestAddress = erc1155QuestAddress_;
        defaultReferralFeeRecipient = defaultReferralFeeRecipientAddress_;
        sablierV2LockupLinearAddress = sablierV2LockupLinearAddress_;
        nftQuestFee = nftQuestFee_;
        referralFee = referralFee_;
        mintFee = mintFee_;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkQuest(string memory questId_, address rewardTokenAddress_) {
        Quest storage currentQuest = quests[questId_];
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();
        if (!rewardAllowlist[rewardTokenAddress_]) revert RewardNotAllowed();
        if (erc20QuestAddress == address(0)) revert Erc20QuestAddressNotSet();
        _;
    }

    modifier claimChecks(ClaimData memory claimData_) {
        Quest storage currentQuest = quests[claimData_.questId];

        if (currentQuest.numberMinted + 1 > currentQuest.totalParticipants) revert OverMaxAllowedToMint();
        if (currentQuest.addressMinted[claimData_.claimer]) revert AddressAlreadyMinted();
        if (recoverSigner(claimData_.hashBytes, claimData_.signature) != claimSignerAddress) revert AddressNotSigned();
        _;
    }

    /// @dev ReentrancyGuard modifier from solmate, copied here because it was added after storage layout was finalized on first deploy
    /// @dev from https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol
    modifier nonReentrant() virtual {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    modifier nonZeroAddress(address address_) {
        if (address_ == address(0)) revert ZeroAddressNotAllowed();
        _;
    }

    modifier sufficientMintFee() {
        if (msg.value < mintFee) revert InvalidMintFee();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 CREATE
    //////////////////////////////////////////////////////////////*/

    function createSoulbound20(
        string memory name_,
        string memory symbol_
    ) external returns (address) {
        // todo check msg.value >= create soulbound fee

        address soulboundAddress = address(soulbound20Address).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, block.chainid, block.timestamp)));
        SoulBound20 soulBound = SoulBound20(soulboundAddress);
        soulBound.initialize(address(this), address(this), name_, symbol_);

        ownerPointAddresses[msg.sender].push(soulboundAddress);
        soulbound2OState[soulboundAddress] = 1;

        // todo emit event
        return soulboundAddress;
    }

    // todo change from onlyOwner to role
    // 0 -> removed or not set
    // 1 -> set but not verified
    // 2 -> verified
    function setSoulBound20AddressState(address soulbound20Address_, uint256 state_) external onlyOwner {
        if(soulbound2OState[soulbound20Address_]){
            soulbound2OState[soulbound20Address_] = state_;
            // todo emit event
        }
    }


    /// @dev Create an erc1155 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param tokenId_ The reward token id of the erc1155 at rewardTokenAddress_
    /// @param questId_ The id of the quest
    /// @param actionType_ The action type for the quest
    /// @param questName_ The name of the quest
    /// @return address the quest contract address
    function createERC1155Quest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 tokenId_,
        string memory questId_,
        string memory actionType_,
        string memory questName_
    ) external payable nonReentrant returns (address) {
        return createERC1155QuestInternal(
            ERC1155QuestData(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_,
                questId_,
                actionType_,
                questName_
            )
        );
    }

    /// @notice Depricated
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
        string memory
    ) external payable nonReentrant returns (address) {
        return createERC1155QuestInternal(
            ERC1155QuestData(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_,
                questId_,
                "",
                ""
            )
        );
    }

    /// @dev Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionType_ The action type for the quest
    /// @param questName_ The name of the quest
    /// @return address the quest contract address
    function createERC20Quest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionType_,
        string memory questName_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        return createERC20QuestInternal(
            ERC20QuestData(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_,
                questId_,
                actionType_,
                questName_,
                0,
                "erc20"
            )
        );
    }

    /// @notice Depricated
    /// @dev Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @return address the quest contract address
    function createQuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory,
        uint256
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        return createERC20QuestInternal(
            ERC20QuestData(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_,
                questId_,
                "",
                "",
                0,
                "erc20"
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/
    /// @dev Claim rewards for a quest
    /// @param compressedData_ The claim data in abi encoded bytes, compressed with cdCompress from solady LibZip
    function claimCompressed(bytes calldata compressedData_) external payable {
        if(tx.origin != msg.sender) revert txOriginMismatch();

        bytes memory data_ = LibZip.cdDecompress(compressedData_);

        (
            bytes32 txHash_,
            bytes32 r_,
            bytes32 vs_,
            address ref_,
            bytes16 questid_,
            uint32 txHashChainId_
        ) = abi.decode(
            data_,
            (bytes32, bytes32, bytes32, address, bytes16, uint32)
        );

        string memory questIdString_ = bytes16ToUUID(questid_);
        Quest storage quest_ = quests[questIdString_];
        string memory jsonData_ = buildJsonString(uint256(txHash_).toHexString(32), uint256(txHashChainId_).toString(), quest_.actionType, quest_.questName);
        bytes memory claimData_ = abi.encode(msg.sender, ref_, questIdString_, jsonData_);

        this.claimOptimized{value: msg.value}(abi.encodePacked(r_,vs_), claimData_);
    }

    /// @notice External use is depricated
    /// @dev Claim rewards for a quest
    /// @param data_ The claim data in abi encoded bytes
    /// @param signature_ The signature of the claim data
    function claimOptimized(bytes calldata signature_, bytes calldata data_) external payable {
        (
            address claimer_,
            address ref_,
            string memory questId_,
            string memory jsonData_
        ) = abi.decode(
            data_,
            (address, address, string, string)
        );
        Quest storage quest = quests[questId_];
        uint256 numberMintedPlusOne_ = quest.numberMinted + 1;
        address rewardToken_ = IQuestOwnable(quest.questAddress).rewardToken();
        uint256 rewardAmountOrTokenId;

        if (recoverSigner(keccak256(data_), signature_) != claimSignerAddress) revert AddressNotSigned();
        if (msg.value < mintFee) revert InvalidMintFee();
        if (quest.addressMinted[claimer_]) revert AddressAlreadyMinted();
        if (numberMintedPlusOne_ > quest.totalParticipants) revert OverMaxAllowedToMint();

        quest.addressMinted[claimer_] = true;
        quest.numberMinted = numberMintedPlusOne_;
        (bool success_, ) = quest.questAddress.call{value: msg.value}(abi.encodeWithSignature("claimFromFactory(address,address)", claimer_, ref_));
        if (!success_) revert ClaimFailed();

        emit QuestClaimedData(claimer_, quest.questAddress, jsonData_);
        if (quest.questType.eq("erc1155")) {
            rewardAmountOrTokenId = IQuest1155Ownable(quest.questAddress).tokenId();
            emit Quest1155Claimed(claimer_, quest.questAddress, questId_, rewardToken_, rewardAmountOrTokenId);
        } else {
            rewardAmountOrTokenId = IQuestOwnable(quest.questAddress).rewardAmountInWei();
            emit QuestClaimed(claimer_, quest.questAddress, questId_, rewardToken_, rewardAmountOrTokenId);
        }
        if(ref_ != address(0)){
            emit QuestClaimedReferred(claimer_, quest.questAddress, questId_, rewardToken_, rewardAmountOrTokenId, ref_, 3333, mintFee);
            emit MintFeePaid(questId_, address(0), 0, address(0), 0, ref_, mintFee / 3);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /// @dev set the claim signer address
    /// @param claimSignerAddress_ The address of the claim signer
    function setClaimSignerAddress(address claimSignerAddress_) external onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    /// @dev set erc1155QuestAddress
    /// @param erc1155QuestAddress_ The address of the erc1155 quest
    function setErc1155QuestAddress(address erc1155QuestAddress_) external onlyOwner {
        erc1155QuestAddress = erc1155QuestAddress_;
    }

    /// @dev set erc20QuestAddress
    /// @param erc20QuestAddress_ The address of the erc20 quest
    function setErc20QuestAddress(address erc20QuestAddress_) external onlyOwner {
        erc20QuestAddress = erc20QuestAddress_;
    }

    /// @dev set the mint fee
    /// @notice the mint fee in ether
    /// @param mintFee_ The mint fee value
    function setMintFee(uint256 mintFee_) external onlyOwner {
        mintFee = mintFee_;
        emit MintFeeSet(mintFee_);
    }

    /// @dev set the nftQuestFee
    /// @param nftQuestFee_ The value of the nftQuestFee
    function setNftQuestFee(uint256 nftQuestFee_) external onlyOwner {
        nftQuestFee = nftQuestFee_;
        emit NftQuestFeeSet(nftQuestFee_);
    }

    /// @dev set the protocol fee recipient
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient
    function setProtocolFeeRecipient(address protocolFeeRecipient_) external onlyOwner {
        if (protocolFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    /// @dev set the quest fee
    /// @notice the quest fee should be in Basis Point units
    /// @param questFee_ The quest fee value
    function setQuestFee(uint16 questFee_) external onlyOwner {
        if (questFee_ > 10_000) revert QuestFeeTooHigh();
        questFee = questFee_;
    }

    /// @dev set the referral fee
    /// @param referralFee_ The value of the referralFee
    function setReferralFee(uint16 referralFee_) external onlyOwner {
        if (referralFee_ > 10_000) revert ReferralFeeTooHigh();
        referralFee = referralFee_;
        emit ReferralFeeSet(referralFee_);
    }

    /// @dev set sablierV2LockupLinearAddress
    /// @param sablierV2LockupLinearAddress_ The address of the sablierV2LockupLinear contract
    function setSablierV2LockupLinearAddress(address sablierV2LockupLinearAddress_) external onlyOwner {
        sablierV2LockupLinearAddress = sablierV2LockupLinearAddress_;
        emit SablierV2LockupLinearAddressSet(sablierV2LockupLinearAddress_);
    }

    /// @dev set or remave a contract address to be used as a reward
    /// @param rewardAddress_ The contract address to set
    /// @param allowed_ Whether the contract address is allowed or not
    function setRewardAllowlistAddress(address rewardAddress_, bool allowed_) external onlyOwner {
        rewardAllowlist[rewardAddress_] = allowed_;
    }

    /// @dev set the mintFeeRecipient
    /// @param mintFeeRecipient_ The address of the mint fee recipient
    function setDefaultMintFeeRecipient(address mintFeeRecipient_) external onlyOwner {
        if (mintFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        defaultMintFeeRecipient = mintFeeRecipient_;
    }

    /// @dev set a mintFeeRecipient for a specific address
    /// @param address_ The address of the account
    /// @param mintFeeRecipient_ The address of the mint fee recipient
    function setMintFeeRecipientForAddress(address address_, address mintFeeRecipient_) external onlyOwner {
        mintFeeRecipientList[address_] = mintFeeRecipient_;
    }

    /// @dev set the nft quest fee for a list of addresses
    /// @param toAddAddresses_ The list of addresses to set the nft quest fee for
    /// @param fees_ The list of fees to set
    function setNftQuestFeeList(address[] calldata toAddAddresses_, uint256[] calldata fees_) external onlyOwner {
        for (uint256 i = 0; i < toAddAddresses_.length; i++) {
            nftQuestFeeList[toAddAddresses_[i]] = NftQuestFees(fees_[i], true);
        }
        emit NftQuestFeeListSet(toAddAddresses_, fees_);
    }

    /// @dev set the default referral fee recipient
    /// @param defaultReferralFeeRecipient_ The address of the default referral fee recipient
    function setDefaultReferralFeeRecipient(address defaultReferralFeeRecipient_) external onlyOwner {
        defaultReferralFeeRecipient = defaultReferralFeeRecipient_;
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice This function name is a bit of a misnomer - gets whether an address has claimed a quest yet.
    /// @dev return status of whether an address has claimed a quest
    /// @param questId_ The id of the quest
    /// @param address_ The address to check
    /// @return claimed status
    function getAddressMinted(string memory questId_, address address_) external view returns (bool) {
        return quests[questId_].addressMinted[address_];
    }

    /// @dev get the mintFeeRecipient return the protocol fee recipient if the mint fee recipient is not set
    /// @param questCreatorAddress_ The address of the quest creator, to get the mintFee
    /// @return address the mint fee recipient
    function getMintFeeRecipient(address questCreatorAddress_) public view returns (address) {
        address _mintFeeRecipient = mintFeeRecipientList[questCreatorAddress_];
        return _mintFeeRecipient == address(0) ? defaultMintFeeRecipient : _mintFeeRecipient;
    }

    function getNftQuestFee(address address_) public view returns (uint256) {
        return nftQuestFeeList[address_].exists ? nftQuestFeeList[address_].fee : nftQuestFee;
    }

    /// @dev return the number of quest claims
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
            thisQuest.numberMinted,
            rewardAmountOrTokenId,
            questContract.hasWithdrawn()
        );

        return data;
    }

    /// @dev return data in the quest struct for a questId
    /// @param questId_ The id of the quest
    function questInfo(string memory questId_) external view returns (address, uint256, uint256) {
        Quest storage currentQuest = quests[questId_];
        return (currentQuest.questAddress, currentQuest.totalParticipants, currentQuest.numberMinted);
    }

    /// @dev recover the signer from a hash and signature
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function recoverSigner(bytes32 hash_, bytes memory signature_) public view returns (address) {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash_), signature_);
    }

    function totalQuestNFTFee(uint256 totalParticipants_) public view returns (uint256) {
        return totalParticipants_ * getNftQuestFee(msg.sender);
    }

    function withdrawCallback(string calldata questId_, address protocolFeeRecipient_, uint protocolPayout_, address mintFeeRecipient_, uint mintPayout) external {
        Quest storage quest = quests[questId_];
        if(msg.sender != quest.questAddress) revert QuestAddressMismatch();

        emit MintFeePaid(questId_, protocolFeeRecipient_, protocolPayout_, mintFeeRecipient_, mintPayout, address(0), 0);
    }

    function getQuestName(string calldata questId_) external view returns (string memory) {
        return quests[questId_].questName;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/

    /// @dev claim rewards for a quest with a referral address
    /// @param claimData_ The claim data struct
    function claim1155RewardsRef(ClaimData memory claimData_) private
        nonReentrant
        sufficientMintFee
        claimChecks(claimData_)
    {
        Quest storage currentQuest = quests[claimData_.questId];
        IQuest1155Ownable questContract_ = IQuest1155Ownable(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[claimData_.claimer] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(claimData_.claimer);

        if (mintFee > 0) {
            string memory newJson = processMintFee(claimData_.ref, currentQuest.questCreator, claimData_.questId);
            if (bytes(claimData_.extraData).length > 0){
                claimData_.extraData = claimData_.extraData.slice(0, bytes(claimData_.extraData).length -1).concat(newJson);
            }
        }

        emit QuestClaimedData(
            claimData_.claimer,
            currentQuest.questAddress,
            claimData_.extraData
        );

        emit Quest1155Claimed(
            claimData_.claimer, currentQuest.questAddress, claimData_.questId, questContract_.rewardToken(), questContract_.tokenId()
        );

        if (claimData_.ref != address(0)) {
            emit QuestClaimedReferred(
                claimData_.claimer,
                currentQuest.questAddress,
                claimData_.questId,
                questContract_.rewardToken(),
                questContract_.tokenId(),
                claimData_.ref,
                3333, //referralFee,
                mintFee
                );
        }
    }

    /// @dev claim rewards with a referral address
    /// @param claimData_ The claim data struct
    function claimRewardsRef(ClaimData memory claimData_) private
        nonReentrant
        sufficientMintFee
        claimChecks(claimData_)
    {
        Quest storage currentQuest = quests[claimData_.questId];
        IQuestOwnable questContract_ = IQuestOwnable(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[claimData_.claimer] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(claimData_.claimer);

        if (mintFee > 0) {
            string memory newJson = processMintFee(claimData_.ref, currentQuest.questCreator, claimData_.questId);
            if (bytes(claimData_.extraData).length > 0){
                claimData_.extraData = claimData_.extraData.slice(0, bytes(claimData_.extraData).length -1).concat(newJson);
            }
        }

        emit QuestClaimedData(
            claimData_.claimer,
            currentQuest.questAddress,
            claimData_.extraData
        );

        emit QuestClaimed(
            claimData_.claimer,
            currentQuest.questAddress,
            claimData_.questId,
            questContract_.rewardToken(),
            questContract_.rewardAmountInWei()
        );

        if (claimData_.ref != address(0)) {
            emit QuestClaimedReferred(
                claimData_.claimer,
                currentQuest.questAddress,
                claimData_.questId,
                questContract_.rewardToken(),
                questContract_.rewardAmountInWei(),
                claimData_.ref,
                3333, //referralFee,
                mintFee
            );
        }
    }

    /// @dev Internal function to create an erc1155 quest
    /// @param data_ The erc20 quest data struct
    function createERC1155QuestInternal(ERC1155QuestData memory data_) internal returns (address) {
        Quest storage currentQuest = quests[data_.questId];

        if (msg.value < totalQuestNFTFee(data_.totalParticipants)) revert MsgValueLessThanQuestNFTFee();
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();

        address payable newQuest =
            payable(erc1155QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, block.chainid, block.timestamp))));
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = data_.totalParticipants;
        currentQuest.questAddress.safeTransferETH(msg.value);
        currentQuest.questType = "erc1155";
        currentQuest.questCreator = msg.sender;
        currentQuest.actionType = data_.actionType;
        currentQuest.questName = data_.questName;
        IQuest1155Ownable questContract = IQuest1155Ownable(newQuest);

        questContract.initialize(
            data_.rewardTokenAddress,
            data_.endTime,
            data_.startTime,
            data_.totalParticipants,
            data_.tokenId,
            protocolFeeRecipient,
            data_.questId
        );

        IERC1155(data_.rewardTokenAddress).safeTransferFrom(msg.sender, newQuest, data_.tokenId, data_.totalParticipants, "0x00");
        questContract.queue();
        questContract.transferOwnership(msg.sender);

        emit QuestCreated(
            msg.sender,
            address(newQuest),
            data_.questId,
            "erc1155",
            data_.rewardTokenAddress,
            data_.endTime,
            data_.startTime,
            data_.totalParticipants,
            data_.tokenId
        );

        return newQuest;
    }

    /// @dev Internal function to create an erc20 quest
    /// @param data_ The erc20 quest data struct
    function createERC20QuestInternal(ERC20QuestData memory data_) internal returns (address) {
        Quest storage currentQuest = quests[data_.questId];
        address newQuest = erc20QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, block.chainid, block.timestamp)));

        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = data_.totalParticipants;
        currentQuest.questCreator = msg.sender;
        currentQuest.durationTotal = data_.durationTotal;
        currentQuest.questType = data_.questType;
        currentQuest.actionType = data_.actionType;
        currentQuest.questName = data_.questName;

        emit QuestCreated(
            msg.sender,
            address(newQuest),
            data_.questId,
            currentQuest.questType,
            data_.rewardTokenAddress,
            data_.endTime,
            data_.startTime,
            data_.totalParticipants,
            data_.rewardAmount
        );

        IQuestOwnable(newQuest).initialize(
            data_.rewardTokenAddress,
            data_.endTime,
            data_.startTime,
            data_.totalParticipants,
            data_.rewardAmount,
            data_.questId,
            questFee,
            protocolFeeRecipient,
            data_.durationTotal,
            sablierV2LockupLinearAddress
        );

        transferTokensAndOwnership(newQuest, data_.rewardTokenAddress);
        return newQuest;
    }

    function processMintFee(address ref_, address mintFeeRecipient_, string memory questId_) private returns (string memory) {
        returnChange();
        uint256 cachedMintFee = mintFee;
        uint256 oneThirdMintfee = cachedMintFee / 3;
        uint256 protocolPayout;
        uint256 mintPayout;
        uint256 referrerPayout;

        if(ref_ == address(0)){
            protocolPayout = oneThirdMintfee * 2;
            mintPayout = oneThirdMintfee;
        } else {
            protocolPayout = oneThirdMintfee;
            mintPayout = oneThirdMintfee;
            referrerPayout = oneThirdMintfee;
        }

        protocolFeeRecipient.safeTransferETH(protocolPayout);
        mintFeeRecipient_.safeTransferETH(mintPayout);
        if(referrerPayout != 0) ref_.safeTransferETH(referrerPayout);

        emit MintFeePaid(questId_, protocolFeeRecipient, protocolPayout, mintFeeRecipient_, mintPayout, ref_, referrerPayout);

        return string(abi.encodePacked(
            ', "claimFee": "', cachedMintFee.toString(),
            '", "claimFeePayouts": [{"name": "protocolPayout", "address": "', protocolFeeRecipient.toHexString(),
            '", "value": "', protocolPayout.toString(),
            '"}, {"name": "mintPayout", "address": "', mintFeeRecipient_.toHexString(),
            '", "value": "', mintPayout.toString(),
            '"}, {"name": "referrerPayout", "address": "', ref_.toHexString(),
            '", "value": "', referrerPayout.toString(), '"}]}'
        ));
    }

    // Refund any excess payment
    function returnChange() private {
        uint256 change = msg.value - mintFee;
        if (change > 0) {
            msg.sender.safeTransferETH(change);
        }
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

    function buildJsonString(
        string memory txHash,
        string memory txHashChainId,
        string memory actionType,
        string memory questName
    ) internal pure returns (string memory) {
        // {
        //     actionTxHashes: ["actionTxHash1"],
        //     actionNetworkChainIds: ["chainId1"],
        //     questName: "quest name",
        //     actionType: "mint"
        // }
        return string(abi.encodePacked(
            '{"actionTxHashes":["', txHash,
            '"],"actionNetworkChainIds":[', txHashChainId,
            '],"questName":"', questName,
            '","actionType":"', actionType, '"}'
        ));
    }

    /// @dev Convert bytes16 to a UUID string e.g. 550e8400-e29b-41d4-a716-446655440000
    /// @param data The bytes16 data e.g. 0x550e8400e29b41d4a716446655440000
    function bytes16ToUUID(bytes16 data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory uuid = new bytes(36); // UUID length with hyphens

        uint256 j = 0; // Position in uuid
        for (uint256 i = 0; i < 16; i++) {
            // Insert hyphens at the appropriate positions (after 4, 6, 8, 10 bytes)
            if (i == 4 || i == 6 || i == 8 || i == 10) {
                uuid[j++] = '-';
            }

            uuid[j++] = hexChars[uint8(data[i] >> 4)];
            uuid[j++] = hexChars[uint8(data[i] & 0x0F)];
        }

        return string(uuid);
    }

    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/
    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}