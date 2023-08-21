// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract QuestFactoryMock {
    uint256 numberMinted;

    function setNumberMinted(uint256 numberminted_) external {
        numberMinted = numberminted_;
    }

    function getNumberMinted(string memory questId_) external view returns (uint256) {
        return numberMinted;
    }
}
