// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "openzeppelin-contracts/governance/Governor.sol";
import "openzeppelin-contracts/governance/extensions/GovernorSettings.sol";
import "openzeppelin-contracts/governance/extensions/GovernorCountingSimple.sol";
import "openzeppelin-contracts/governance/extensions/GovernorVotes.sol";
import "openzeppelin-contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IGovernor} from "openzeppelin-contracts/governance/IGovernor.sol";

contract MyGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction {
    constructor(IVotes _token)
        Governor("MyGovernor")
        GovernorSettings(86400 /* 1 day */, 259200 /* 3 days */, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}