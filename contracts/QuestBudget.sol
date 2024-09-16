// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";

import {IERC1155Receiver} from "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

import {Budget} from "contracts/references/Budget.sol";
import {Cloneable} from "contracts/references/Cloneable.sol";

/// @title Simple Budget
/// @notice A minimal budget implementation that simply holds and distributes tokens (ERC20-like and native)
/// @dev This type of budget supports ETH, ERC20, and ERC1155 assets only
contract QuestBudget is Budget, IERC1155Receiver, ReentrancyGuard {
    using SafeTransferLib for address;
    using SafeERC20 for IERC20;

    /// @notice The payload for initializing a SimpleBudget
    struct InitPayload {
        address owner;
        address questFactory;
        address[] authorized;
    }

    // @dev The address of the QuestFactory contract
    address public questFactory;

    bool public disburseEnabled;

    /// @dev The total amount of each fungible asset distributed from the budget
    mapping(address => uint256) private _distributedFungible;

    /// @dev The total amount of each ERC1155 asset and token ID distributed from the budget
    mapping(address => mapping(uint256 => uint256)) private _distributedERC1155;

    /// @dev The mapping of authorized addresses
    mapping(address => bool) private _isAuthorized;

    /// @dev The management fee percentage (in basis points, i.e., 100 = 1%)
    uint256 public managementFee;

    /// @dev Mapping of quest IDs to their respective managers' addresses
    mapping(string => address) public questManagers;

    /// @dev Total amount of funds reserved for management fees
    uint256 public reservedFunds;

    /// @dev Emitted when the management fee is set or updated
    event ManagementFeeSet(uint256 newFee);

    /// @dev Emitted when management fee is paid
    event ManagementFeePaid(string indexed questId, address indexed manager, uint256 amount);

    /// @notice A modifier that allows only authorized addresses to call the function
    modifier onlyAuthorized() {
        if (!isAuthorized(msg.sender)) revert Unauthorized();
        _;
    }

    /// @notice Construct a new SimpleBudget
    /// @dev Because this contract is a base implementation, it should not be initialized through the constructor. Instead, it should be cloned and initialized using the {initialize} function.
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc Cloneable
    /// @param data_ The packed init data for the budget `(address owner, address[] authorized)`
    function initialize(bytes calldata data_) public virtual override initializer {
        InitPayload memory init_ = abi.decode(data_, (InitPayload));
        _initializeOwner(init_.owner);
        questFactory = init_.questFactory;
        for (uint256 i = 0; i < init_.authorized.length; i++) {
            _isAuthorized[init_.authorized[i]] = true;
        }
    }

    /// @inheritdoc Budget
    /// @notice Allocates assets to the budget
    /// @param data_ The packed data for the {Transfer} request
    /// @return True if the allocation was successful
    /// @dev The caller must have already approved the contract to transfer the asset
    /// @dev If the asset transfer fails, the allocation will revert
    function allocate(bytes calldata data_) external payable virtual override returns (bool) {
        Transfer memory request = abi.decode(data_, (Transfer));
        if (request.assetType == AssetType.ETH) {
            FungiblePayload memory payload = abi.decode(request.data, (FungiblePayload));

            // Ensure the value received is equal to the `payload.amount`
            if (msg.value != payload.amount) {
                revert InvalidAllocation(request.asset, payload.amount);
            }
        } else if (request.assetType == AssetType.ERC20) {
            FungiblePayload memory payload = abi.decode(request.data, (FungiblePayload));

            // Transfer `payload.amount` of the token to this contract
            request.asset.safeTransferFrom(request.target, address(this), payload.amount);
            if (request.asset.balanceOf(address(this)) < payload.amount) {
                revert InvalidAllocation(request.asset, payload.amount);
            }
        } else if (request.assetType == AssetType.ERC1155) {
            ERC1155Payload memory payload = abi.decode(request.data, (ERC1155Payload));

            // Transfer `payload.amount` of `payload.tokenId` to this contract
            IERC1155(request.asset).safeTransferFrom(
                request.target, address(this), payload.tokenId, payload.amount, payload.data
            );
            if (IERC1155(request.asset).balanceOf(address(this), payload.tokenId) < payload.amount) {
                revert InvalidAllocation(request.asset, payload.amount);
            }
        } else {
            // Unsupported asset type
            return false;
    }

        return true;
    }

    /// @inheritdoc Budget
    /// @notice Reclaims assets from the budget
    /// @param data_ The packed {Transfer} request
    /// @return True if the request was successful
    /// @dev Only the owner can directly reclaim assets from the budget
    /// @dev If the amount is zero, the entire balance of the asset will be transferred to the receiver
    /// @dev If the asset transfer fails, the reclamation will revert
    function reclaim(bytes calldata data_) external virtual override onlyOwner returns (bool) {
        Transfer memory request = abi.decode(data_, (Transfer));
        if (request.assetType == AssetType.ETH || request.assetType == AssetType.ERC20) {
            FungiblePayload memory payload = abi.decode(request.data, (FungiblePayload));
            _transferFungible(
                request.asset, request.target, payload.amount == 0 ? available(request.asset) : payload.amount
            );
        } else if (request.assetType == AssetType.ERC1155) {
            ERC1155Payload memory payload = abi.decode(request.data, (ERC1155Payload));
            _transferERC1155(
                request.asset,
                request.target,
                payload.tokenId,
                payload.amount == 0 ? IERC1155(request.asset).balanceOf(address(this), payload.tokenId) : payload.amount,
                payload.data
            );
        } else {
            return false;
        }

        return true;
    }

    /// @notice Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param txHashChainId_ The chain id of the chain the txHash is on
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionType_ The action type for the quest
    /// @param questName_ The name of the quest
    /// @param projectName_ The name of the project/protocol used for the quest
    /// @param referralRewardFee_ The fee amount for referrals. The value is counted against the `rewardAmount`
    /// @return address the quest contract address
    function createERC20Quest(
        uint32 txHashChainId_,
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionType_,
        string memory questName_,
        string memory projectName_,
        uint256 referralRewardFee_
    ) public virtual onlyAuthorized returns (address) {
        uint256 maxTotalRewards = totalParticipants_ * rewardAmount_;
        uint256 questFee = uint256(IQuestFactory(questFactory).questFee());
        uint256 referralRewardFee = uint256(IQuestFactory(questFactory).referralRewardFee());
        uint256 maxProtocolReward = (maxTotalRewards * questFee) / 10_000;
        uint256 maxReferralReward = (maxTotalRewards * referralRewardFee) / 10_000;
        uint256 maxManagementFee = (maxTotalRewards * managementFee) / 10_000;
        uint256 approvalAmount = maxTotalRewards + maxProtocolReward + maxReferralReward;

        // Ensure the available balance in the budget can cover the required approval amount plus the reserved management fee
        require(
            this.available(rewardTokenAddress_) >= approvalAmount + maxManagementFee,
            "Insufficient funds for quest creation"
        );

        // Reserve the management fee so that the manager can be paid later
        reservedFunds += maxManagementFee;

        // Approve the QuestFactory contract to transfer the necessary tokens for this quest
        rewardTokenAddress_.safeApprove(address(questFactory), approvalAmount);

        // Store the manager address (msg.sender) associated with the questId
        questManagers[questId_] = msg.sender;

        return IQuestFactory(questFactory).createERC20Quest(
            txHashChainId_,
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            actionType_,
            questName_,
            projectName_,
            referralRewardFee_
        );
    }

    /// @notice Cancel a quest
    /// @param questId_ The uuid of the quest
    function cancelQuest(string calldata questId_) public virtual onlyOwner() {
        IQuestFactory(questFactory).cancelQuest(questId_);
    }

    /// @notice Sets the management fee percentage
    /// @dev Only the owner can call this function. The fee is in basis points (100 = 1%)
    /// @param fee_ The new management fee percentage in basis points
    function setManagementFee(uint256 fee_) external onlyOwner {
        require(fee_ <= 10000, "Fee cannot exceed 100%");
        managementFee = fee_;
        emit ManagementFeeSet(fee_);
    }

    /// @notice Allows the quest manager to claim the management fee for a completed quest
    /// @dev This function can only be called by the authorized quest manager after the quest rewards have been withdrawn
    /// @param questId_ The unique identifier of the quest for which the management fee is being claimed
    function payManagementFee(string memory questId_) public onlyAuthorized {
        // Retrieve the quest data by calling the questData function and decoding the result
        IQuestFactory.QuestData memory quest = IQuestFactory(questFactory).questData(questId_);

        // Ensure the caller is the manager who created the quest
        require(questManagers[questId_] == msg.sender, "Only the quest creator can claim the management fee");

        // Ensure the quest has been marked as withdrawn
        require(quest.hasWithdrawn, "Management fee cannot be claimed until the quest rewards are withdrawn");

        // Extract relevant data from the QuestData struct
        uint256 totalParticipants = quest.totalParticipants;
        uint256 rewardAmount = quest.rewardAmountOrTokenId;
        uint256 numberMinted = quest.numberMinted;

        // Calculate the maximum possible management fee based on total participants
        uint256 totalPossibleFee = (totalParticipants * rewardAmount * managementFee) / 10_000;

        // Calculate the actual management fee to be paid based on the number of claims (numberMinted)
        uint256 feeToPay = (numberMinted * rewardAmount * managementFee) / 10_000;

        // Get the balance of reward tokens available in this contract
        uint256 availableFunds = IERC20(quest.rewardToken).balanceOf(address(this));

        // Ensure the contract has enough funds to pay out the management fee; they should be reserved and not available
        require(availableFunds >= feeToPay, "Insufficient funds to pay management fee");

        // Transfer the management fee to the manager
        IERC20(quest.rewardToken).safeTransfer(msg.sender, feeToPay);

        // Subtract the total possible management fee since we reserved the total amount to begin with
        reservedFunds = reservedFunds - totalPossibleFee;

        // Emit an event for logging purposes
        emit ManagementFeePaid(questId_, msg.sender, feeToPay);
    }
 
    /// @inheritdoc Budget
    /// @notice Disburses assets from the budget to a single recipient
    /// @param data_ The packed {Transfer} request
    /// @return True if the disbursement was successful
    /// @dev If the asset transfer fails, the disbursement will revert
    function disburse(bytes calldata data_) public virtual override onlyAuthorized returns (bool) {
        if(!disburseEnabled) {
            revert Unauthorized();
        }
        Transfer memory request = abi.decode(data_, (Transfer));
        if (request.assetType == AssetType.ERC20 || request.assetType == AssetType.ETH) {
            FungiblePayload memory payload = abi.decode(request.data, (FungiblePayload));

            uint256 avail = available(request.asset);
            if (payload.amount > avail) {
                revert InsufficientFunds(request.asset, avail, payload.amount);
            }

            _transferFungible(request.asset, request.target, payload.amount);
        } else if (request.assetType == AssetType.ERC1155) {
            ERC1155Payload memory payload = abi.decode(request.data, (ERC1155Payload));

            uint256 avail = IERC1155(request.asset).balanceOf(address(this), payload.tokenId);
            if (payload.amount > avail) {
                revert InsufficientFunds(request.asset, avail, payload.amount);
            }

            _transferERC1155(request.asset, request.target, payload.tokenId, payload.amount, payload.data);
        } else {
            return false;
        }

        return true;
    }

    /// @inheritdoc Budget
    /// @notice Disburses assets from the budget to multiple recipients
    /// @param data_ The packed array of {Transfer} requests
    /// @return True if all disbursements were successful
    function disburseBatch(bytes[] calldata data_) external virtual override returns (bool) {
        for (uint256 i = 0; i < data_.length; i++) {
            if (!disburse(data_[i])) return false;
        }

        return true;
    }

    /// @inheritdoc Budget
    function setAuthorized(address[] calldata account_, bool[] calldata authorized_)
        external
        virtual
        override
        onlyOwner
    {
        if (account_.length != authorized_.length) revert LengthMismatch();
        for (uint256 i = 0; i < account_.length; i++) {
            _isAuthorized[account_[i]] = authorized_[i];
        }
    }

    /// @inheritdoc Budget
    function isAuthorized(address account_) public view virtual override returns (bool) {
        return _isAuthorized[account_] || account_ == owner();
    }

    /// @notice Set the QuestFactory contract address
    /// @param questFactory_ The address of the QuestFactory contract
    function setQuestFactory(address questFactory_) external virtual onlyOwner {
        questFactory = questFactory_;
    }

    /// @notice Set the DisburseEnabled flag
    /// @param enabled_ The flag to enable or disable disburse
    function setDisburseEnabled(bool enabled_) external virtual onlyOwner {
        disburseEnabled = enabled_;
    }

    /// @inheritdoc Budget
    /// @notice Get the total amount of assets allocated to the budget, including any that have been distributed
    /// @param asset_ The address of the asset
    /// @return The total amount of assets
    /// @dev This is simply the sum of the current balance and the distributed amount
    function total(address asset_) external view virtual override returns (uint256) {
        return available(asset_) + _distributedFungible[asset_];
    }

    /// @notice Get the total amount of ERC1155 assets allocated to the budget, including any that have been distributed
    /// @param asset_ The address of the asset
    /// @param tokenId_ The ID of the token
    /// @return The total amount of assets
    function total(address asset_, uint256 tokenId_) external view virtual returns (uint256) {
        return IERC1155(asset_).balanceOf(address(this), tokenId_) + _distributedERC1155[asset_][tokenId_];
    }

    /// @inheritdoc Budget
    /// @notice Get the amount of assets available for distribution from the budget
    /// @param asset_ The address of the asset (or the zero address for native assets)
    /// @return The amount of assets available
    /// @dev This returns the current balance held by the budget minus reserved funds
    /// @dev If the zero address is passed, this function will return the native balance
    function available(address asset_) public view virtual override returns (uint256) {
        uint256 totalBalance = asset_ == address(0) ? address(this).balance : IERC20(asset_).balanceOf(address(this));
        return totalBalance > reservedFunds ? totalBalance - reservedFunds : 0;
    }

    /// @notice Get the amount of ERC1155 assets available for distribution from the budget
    /// @param asset_ The address of the asset
    /// @param tokenId_ The ID of the token
    /// @return The amount of assets available
    function available(address asset_, uint256 tokenId_) public view virtual returns (uint256) {
        return IERC1155(asset_).balanceOf(address(this), tokenId_);
    }

    /// @inheritdoc Budget
    /// @notice Get the amount of assets that have been distributed from the budget
    /// @param asset_ The address of the asset
    /// @return The amount of assets distributed
    function distributed(address asset_) external view virtual override returns (uint256) {
        return _distributedFungible[asset_];
    }

    /// @notice Get the amount of ERC1155 assets that have been distributed from the budget
    /// @param asset_ The address of the asset
    /// @param tokenId_ The ID of the token
    /// @return The amount of assets distributed
    function distributed(address asset_, uint256 tokenId_) external view virtual returns (uint256) {
        return _distributedERC1155[asset_][tokenId_];
    }

    /// @inheritdoc Budget
    /// @dev This is a no-op as there is no local balance to reconcile
    function reconcile(bytes calldata) external virtual override returns (uint256) {
        return 0;
    }

    /// @notice Transfer assets to the recipient
    /// @param asset_ The address of the asset
    /// @param to_ The address of the recipient
    /// @param amount_ The amount of the asset to transfer
    /// @dev This function is used to transfer assets from the budget to a given recipient (typically an incentive contract)
    /// @dev If the destination address is the zero address, or the transfer fails for any reason, this function will revert
    function _transferFungible(address asset_, address to_, uint256 amount_) internal virtual nonReentrant {
        // Increment the total amount of the asset distributed from the budget
        if (to_ == address(0)) revert TransferFailed(asset_, to_, amount_);
        if (amount_ > available(asset_)) {
            revert InsufficientFunds(asset_, available(asset_), amount_);
        }

        _distributedFungible[asset_] += amount_;

        // Transfer the asset to the recipient
        if (asset_ == address(0)) {
            SafeTransferLib.safeTransferETH(to_, amount_);
        } else {
            asset_.safeTransfer(to_, amount_);
        }

        emit Distributed(asset_, to_, amount_);
    }

    function _transferERC1155(address asset_, address to_, uint256 tokenId_, uint256 amount_, bytes memory data_)
        internal
        virtual
        nonReentrant
    {
        // Increment the total amount of the asset distributed from the budget
        if (to_ == address(0)) revert TransferFailed(asset_, to_, amount_);
        if (amount_ > available(asset_, tokenId_)) {
            revert InsufficientFunds(asset_, available(asset_, tokenId_), amount_);
        }

        _distributedERC1155[asset_][tokenId_] += amount_;

        // Transfer the asset to the recipient
        // wake-disable-next-line reentrancy (`nonReentrant` modifier is applied to the function)
        IERC1155(asset_).safeTransferFrom(address(this), to_, tokenId_, amount_, data_);

        emit Distributed(asset_, to_, amount_);
    }

    /// @inheritdoc IERC1155Receiver
    /// @dev This contract does not care about the specifics of the inbound token, so we simply return the magic value (i.e. the selector for `onERC1155Received`)
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        // We don't need to do anything here
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    /// @dev This contract does not care about the specifics of the inbound token, so we simply return the magic value (i.e. the selector for `onERC1155Received`)
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        // We don't need to do anything here
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /// @inheritdoc Cloneable
    function supportsInterface(bytes4 interfaceId) public view virtual override(Budget, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}