// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library RayMath {

    uint256 internal constant RAY = 1e27;
    uint256 internal constant halfRAY = RAY / 2;

    function ray() internal pure returns (uint256) {
        return RAY;
    }

    function halfRay() internal pure returns (uint256) {
        return halfRAY;
    }

    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return Math.mulDiv(a, b, RAY, Math.Rounding.Ceil);
    }

    function rayPow(uint256 x, uint256 n) internal pure returns (uint256 z) {

        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rayMul(x, x);

            if (n % 2 != 0) {
                z = rayMul(z, x);
            }
        }
    }
}
