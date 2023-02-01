// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import './ReceiptSVGRenderer.sol';

/// @title ReceiptRenderer
/// @author RabbitHole.gg
/// @dev This contract is used to render on-chain data for RabbitHole Receipts (ERC-721 standard)
contract ReceiptRenderer {
    using Strings for uint256;

    /// @dev generates the tokenURI for a given ERC-721 token ID
    /// @param tokenId_ The token id to generate the URI for
    /// @param questId_ The questId tied to the tokenId
    /// @param totalParticipants_ The total number of participants in the quest
    /// @param claimed_ Whether or not the token has been claimed
    /// @param rewardAmount_ The amount of reward tokens that the user is eligible for
    /// @param rewardAddress_ The address of the reward token
    /// @param svgRendererAddress_ The address of the SVG renderer contract
    /// @return encoded JSON following the generic OpenSea metadata standard
    function generateTokenURI(
        uint tokenId_,
        string memory questId_,
        uint totalParticipants_,
        bool claimed_,
        uint rewardAmount_,
        address rewardAddress_,
        address svgRendererAddress_
    ) public view virtual returns (string memory) {
        bytes memory dataURI = generateDataURI(
            tokenId_,
            questId_,
            totalParticipants_,
            claimed_,
            rewardAmount_,
            rewardAddress_,
            svgRendererAddress_
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    function generateDataURI(
        uint tokenId_,
        string memory questId_,
        uint totalParticipants_,
        bool claimed_,
        uint rewardAmount_,
        address rewardAddress_,
        address svgRendererAddress_
    ) public view virtual returns (bytes memory) {
        bytes memory attributes = abi.encodePacked(
            '[',
            generateAttribute('Quest ID', questId_),
            ',',
            generateAttribute('Token ID', tokenId_.toString()),
            ',',
            generateAttribute('Total Participants', totalParticipants_.toString()),
            ',',
            generateAttribute('Claimed', claimed_ ? 'true' : 'false'),
            ',',
            generateAttribute('Reward Amount', rewardAmount_.toString()),
            ',',
            generateAttribute('Reward Address', Strings.toHexString(uint160(rewardAddress_), 20)),
            ']'
        );
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole.gg Receipt #',
            tokenId_.toString(),
            '",',
            '"description": "RabbitHole.gg Receipts are used to claim rewards from completed quests.",',
            '"image": "',
            ReceiptSVGRenderer(svgRendererAddress_).generateSVG(claimed_, questId_, rewardAmount_, rewardAddress_),
            '",',
            '"attributes": ',
            attributes,
            '}'
        );
        return dataURI;
    }

    /// @dev generates an attribute object for an ERC-721 token
    /// @param key The key for the attribute
    /// @param value The value for the attribute
    function generateAttribute(string memory key, string memory value) public pure returns (string memory) {
        bytes memory attribute = abi.encodePacked(
            '{',
            '"trait_type": "',
            key,
            '",',
            '"value": "',
            value,
            '"',
            '}'
        );
        return string(attribute);
    }
}