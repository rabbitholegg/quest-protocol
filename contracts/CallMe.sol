// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {QuestFactory} from "./QuestFactory.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {LibZip} from "solady/utils/LibZip.sol";

library Calldata {
    function getUint8(uint offset) internal pure returns (uint8 val) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            val := calldataload(offset)
        }
    }

    function getUint96(uint offset) internal pure returns (uint96 val) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            val := calldataload(offset)
        }
    }

    function getAddress(uint offset) internal pure returns (address val) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            val := calldataload(offset)
        }
    }
}

address constant FACTORY_ADDRESS = 0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E;
bytes1 constant CLAIMV1_SELECTOR = bytes1(uint8(1));

contract CallMe is Ownable {
    error ClaimFailed();

    constructor(address owner_) {
        _initializeOwner(owner_);
    }

    fallback(bytes calldata data) payable external {
        bytes memory deData = LibZip.cdDecompress(data);
        bytes1 selector = bytes1(data[:1]);

        if(selector == CLAIMV1_SELECTOR) {
            (
                address ref,
                string memory questId,
                string memory jsonData,
                bytes memory signature
            ) = abi.decode(
                deData[1:],
                (address, string, string, bytes)
            );
            bytes memory claimData = abi.encode(msg.sender, ref, questId, jsonData);

            bytes memory factoryCallData = abi.encodeWithSignature("claimOptimized(bytes,bytes)", signature, claimData);
            (bool success_, ) = FACTORY_ADDRESS.call{value: msg.value}(factoryCallData);
            if (!success_) revert ClaimFailed();
        }
    }
}