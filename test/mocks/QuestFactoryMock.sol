// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract QuestFactoryMock {
    event MintFeePaid(
        string questId,
        address protocolFeeRecipient,
        uint256 protocolPayout,
        address mintFeeRecipient,
        uint256 mintPayout,
        address tokenAddress,
        uint256 tokenId
    );

    function withdrawCallback(string calldata questId_, address protocolFeeRecipient_, uint protocolPayout_, address mintFeeRecipient_, uint mintPayout) external {
        emit MintFeePaid(questId_, protocolFeeRecipient_, protocolPayout_, mintFeeRecipient_, mintPayout, address(0), 0);
    }

    function getAddressMinted(string memory, address) external pure returns (bool) {
        return false;
    }

    function claimCallback(address, address, address, uint256, uint256, string calldata, string calldata) pure external {
        return;
    }
}
