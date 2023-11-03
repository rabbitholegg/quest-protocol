// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {RabbitHoleTickets} from "contracts/RabbitHoleTickets.sol";
import {LibClone} from "solady/utils/LibClone.sol";
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
}
