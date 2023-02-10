// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

/// @title TicketRenderer
/// @author RabbitHole.gg
/// @dev This contract is used to render on-chain data for RabbitHole tickets (aka an 1155 Reward)
contract TicketRenderer {
    using Strings for uint256;

    /// @dev generates the tokenURI for a given 1155 token ID
    /// @param tokenId_ The token id to generate the URI for
    /// @return encoded JSON following the generic OpenSea metadata standard
    function generateTokenURI(
        uint tokenId_
    ) external pure returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole Tickets #',
            tokenId_.toString(),
            '",',
            '"description": "A reward for completing quests within RabbitHole, with unk(no)wn utility",',
            '"image": "',
            generateSVG(tokenId_),
            '"',
            '}'
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    /// @dev generates the on-chain SVG for an 1155 token ID
    /// @param tokenId_ The token id to generate the svg for
    /// @return encoded JSON for an SVG image
    function generateSVG(uint tokenId_) internal pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>',
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">RabbitHole Tickets #',
            tokenId_.toString(),
            '</text>',
            '</svg>'
        );
        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(svg)));
    }
}