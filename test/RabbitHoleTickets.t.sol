// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {RabbitHoleTickets} from "contracts/RabbitHoleTickets.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Base64} from "solady/utils/Base64.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";

contract TestRabbitHoleTickets is Test, Errors, Events {
    using LibClone for address;

    RabbitHoleTickets rabbitHoletTckets;
    address owner = makeAddr(("owner"));
    address minter = makeAddr(("minter"));
    address royaltyRecipient = makeAddr(("royaltyRecipient"));
    address to = makeAddr("to");
    uint256 royaltyFee = 10;
    string imageIPFSCID = "imageIPFSCID";
    string animationUrlIPFSCID = "animationUrlIPFSCID";

    function setUp() public {
        address ticketsAddress = address(new RabbitHoleTickets()).cloneDeterministic(keccak256(abi.encodePacked(msg.sender, "SALT")));
        rabbitHoletTckets = RabbitHoleTickets(ticketsAddress);

        rabbitHoletTckets.initialize(
            royaltyRecipient,
            minter,
            royaltyFee,
            owner,
            imageIPFSCID,
            animationUrlIPFSCID
        );
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function test_initialize() public {
        assertEq(rabbitHoletTckets.owner(), owner);
        assertEq(rabbitHoletTckets.royaltyRecipient(), royaltyRecipient);
        assertEq(rabbitHoletTckets.minterAddress(), minter);
        assertEq(rabbitHoletTckets.royaltyFee(), royaltyFee);
        assertEq(rabbitHoletTckets.imageIPFSCID(), imageIPFSCID);
        assertEq(rabbitHoletTckets.animationUrlIPFSCID(), animationUrlIPFSCID);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/
    function test_mint() public {
        uint256 tokenId = 1;
        uint256 amount = 1;

        vm.prank(minter);
        rabbitHoletTckets.mint(to, tokenId, amount, "");

        assertEq(rabbitHoletTckets.balanceOf(to, tokenId), amount);
    }

    function test_mintBatch() public {
        uint256 tokenId = 1;
        uint256 amount = 1;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(minter);
        rabbitHoletTckets.mintBatch(to, tokenIds, amounts, "");

        assertEq(rabbitHoletTckets.balanceOf(to, tokenId), amount);
    }

    function test_RevertIf_mint_OnlyMinter() public {
        uint256 tokenId = 1;
        uint256 amount = 1;

        vm.expectRevert(abi.encodeWithSelector(OnlyMinter.selector));
        rabbitHoletTckets.mint(to, tokenId, amount, "");
    }

    function test_uri_token_2() public {
        string memory expected = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(abi.encodePacked(
                    '{"name": "2023 RabbitHole Holiday Reward","description": "You unwrapped a Christmas gift from RabbitHole for being a loyal member and completing our 2023 Holiday campaign","image": "ipfs://bafybeigoo4rnwlmeyyq2rgcteqb3srxaida24jpiedxsoqa7cvpbjhnzni","animation_url": "ipfs://bafybeig7sfklww3qsd2yah4tottv6ewvroad5cqidvxswtdrblzvd7gf64"}'
                )))
            )
        );

        assertEq(rabbitHoletTckets.uri(2), expected);
    }
}
