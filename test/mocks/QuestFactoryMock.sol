// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract QuestFactoryMock {
    uint256 numberMinted;
    uint256 public mintFee;

    event MintFeePaid(
        string questId,
        address protocolFeeRecipient,
        uint256 protocolPayout,
        address mintFeeRecipient,
        uint256 mintPayout,
        address tokenAddress,
        uint256 tokenId
    );

    function setNumberMinted(uint256 numberminted_) external {
        numberMinted = numberminted_;
    }

    function setMintFee(uint256 mintFee_) external {
        mintFee = mintFee_;
    }

    function getNumberMinted(string memory) external view returns (uint256) {
        return numberMinted;
    }

    function getAddressMinted(string memory, address) external pure returns (bool) {
        return false;
    }
}
