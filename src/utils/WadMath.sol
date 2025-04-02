// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library WadMath {

    uint256 internal constant WAD = 1e18;
    uint256 internal constant halfWAD = WAD / 2;

    function wad() internal pure returns (uint256) {
        return WAD;
    }

    function halfWad() internal pure returns (uint256) {
        return halfWAD;
    }

    function wadPow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = WAD;

        while (n != 0) {
            uint256 acc = x;

            for (uint8 i = 0; i < 4; ++i) {
                if ((n & (1 << i)) != 0) {
                    z = (z * acc + halfWAD) / WAD;
                }
                acc = (acc * acc + halfWAD) / WAD;
            }

            n >>= 4;

            x = acc;
        }
    }
}
