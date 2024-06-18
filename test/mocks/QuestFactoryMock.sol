// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract QuestFactoryMock {
    uint256 numberMinted;
    uint256 public mintFee;

    struct QuestData {
        uint32 txHashChainId;
        address rewardTokenAddress;
        uint256 endTime;
        uint256 startTime;
        uint256 totalParticipants;
        uint256 rewardAmount;
        string questId;
        string actionType;
        string questName;
        string questType;
        string projectName;
    }

    QuestData public questData;

    event MintFeePaid(
        string questId,
        address protocolFeeRecipient,
        uint256 protocolPayout,
        address mintFeeRecipient,
        uint256 mintPayout,
        address tokenAddress,
        uint256 tokenId
    );

    event QuestCancelled(address indexed questAddress, string questId, uint256 endsAt);


    function setNumberMinted(uint256 numberminted_) external {
        numberMinted = numberminted_;
    }

    function setMintFee(uint256 mintFee_) external {
        mintFee = mintFee_;
    }

    function getNumberMinted(string memory) external view returns (uint256) {
        return numberMinted;
    }

    function withdrawCallback(string calldata questId_, address protocolFeeRecipient_, uint protocolPayout_, address mintFeeRecipient_, uint mintPayout) external {
        emit MintFeePaid(questId_, protocolFeeRecipient_, protocolPayout_, mintFeeRecipient_, mintPayout, address(0), 0);
    }

    function getAddressMinted(string memory, address) external pure returns (bool) {
        return false;
    }

    function questFee() external pure returns (uint16) {
        return 2000;
    }


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
        string memory projectName_
    ) external returns (address) {
            uint256 maxTotalRewards = totalParticipants_ * rewardAmount_;
        uint256 maxProtocolReward = (maxTotalRewards * 2000) / 10_000; // Assuming questFee is 2000
        uint256 approvalAmount = maxTotalRewards + maxProtocolReward;
        questData = QuestData({
            txHashChainId: txHashChainId_,
            rewardTokenAddress: rewardTokenAddress_,
            endTime: endTime_,
            startTime: startTime_,
            totalParticipants: totalParticipants_,
            rewardAmount: rewardAmount_,
            questId: questId_,
            actionType: actionType_,
            questName: questName_,
            questType: "erc20",
            projectName: projectName_
        });

        // Transfer rewardAmount_ tokens from the caller to this contract
        require(IERC20(rewardTokenAddress_).transferFrom(msg.sender, address(this), approvalAmount), "Transfer failed");

        // Return this contract's address as the "created" quest contract
        return address(this);
    }

    function cancelQuest(string calldata questId_) external {
        emit QuestCancelled(address(this), '', 0);
    }

}
