// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibExtraString {
    function stringToAddress(string memory _a) internal pure returns (address) {
        bytes memory tmp = bytes(_a);
        require(tmp.length == 42, "Invalid input length"); // Ethereum addresses have 42 characters (40 for the address, 2 for the '0x' prefix)
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));

            if ((b1 >= 97) && (b1 <= 102)) b1 -= 87;
            else if ((b1 >= 65) && (b1 <= 70)) b1 -= 55;
            else if ((b1 >= 48) && (b1 <= 57)) b1 -= 48;

            if ((b2 >= 97) && (b2 <= 102)) b2 -= 87;
            else if ((b2 >= 65) && (b2 <= 70)) b2 -= 55;
            else if ((b2 >= 48) && (b2 <= 57)) b2 -= 48;

            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}
