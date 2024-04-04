// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/Points.sol";
import {TestUtils} from "./helpers/TestUtils.sol";

contract BoostPassTest is Test, TestUtils {
    Points points;
    address constant ZERO_ADDRESS = address(0);

    function setUp() public {
      points = new Points();
      points.initialize("PointsToken", "PT", msg.sender);
    }

    function test_initialize_sets_correct_values() public {
        // TODO: Implement test
    }

    function test_initialize_grants_issuer_role() public {
        // TODO: Implement test
    }

    function test_issue_mints_correct_amount() public {
        // TODO: Implement test
    }

    function test_issue_requires_issuer_role() public {
        // TODO: Implement test
    }

    function test_hasIssuerRole_returns_correct_value() public {
        // TODO: Implement test
    }

    function test_grantIssuerRole_grants_role() public {
        // TODO: Implement test
    }

    function test_grantIssuerRole_requires_grant_issuer_role() public {
        // TODO: Implement test
    }

    function test_name_returns_correct_value() public {
        // TODO: Implement test
    }

    function test_symbol_returns_correct_value() public {
        // TODO: Implement test
    }

    function test_beforeTokenTransfer_allows_minting() public {
        // TODO: Implement test
    }

    function test_beforeTokenTransfer_allows_burning() public {
        // TODO: Implement test
    }

    function test_beforeTokenTransfer_disallows_transfers() public {
        // TODO: Implement test
    }
}