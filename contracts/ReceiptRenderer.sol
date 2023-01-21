// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

/// @title ReceiptRenderer
/// @author RabbitHole.gg
/// @dev This contract is used to render on-chain data for RabbitHole Receipts (ERC-721 standard)
contract ReceiptRenderer {
    using Strings for uint256;

    /// @dev generates the tokenURI for a given ERC-721 token ID
    /// @param _tokenId The token id to generate the URI for
    /// @param _questId The questId tied to the tokenId
    /// @return encoded JSON following the generic OpenSea metadata standard
    function generateTokenURI(
        uint _tokenId,
        string memory _questId
    ) public view virtual returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole Quest #',
            _questId,
            ' Redeemer #',
            _tokenId.toString(),
            '",',
            '"description": "This is a receipt for a RabbitHole Quest. You can use this receipt to claim a reward on RabbitHole.",',
            '"image": "',
            generateSVG(_tokenId, _questId),
            '"',
            '}'
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    /// @dev generates the on-chain SVG for an ERC-721 token ID
    /// @param _tokenId The token id to generate the svg for
    /// @param _questId The questId tied to the tokenId
    /// @return encoded JSON for an SVG image
    function generateSVG(uint _tokenId, string memory _questId) public pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>',
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Quest #',
            _questId,
            '</text>',
            '<text x="70%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Quest Receipt #',
            _tokenId,
            '</text>',
            '</svg>'
        );
        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(svg)));
    }
}