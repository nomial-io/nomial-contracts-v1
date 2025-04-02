// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {WadMath} from "../src/utils/WadMath.sol";

contract WadMathTest is Test {
    uint constant WAD = 1e18;
    uint constant halfWAD = WAD / 2;

    /**
     * @notice Tests that wad() returns the correct WAD value
     */
    function testWadMath_wad() public {
        assertEq(WadMath.wad(), WAD, "wad() should return 1e18");
    }

    /**
     * @notice Tests that halfWad() returns the correct half WAD value
     */
    function testWadMath_halfWad() public {
        assertEq(WadMath.halfWad(), halfWAD, "halfWad() should return 5e17");
    }

    /**
     * @notice Tests wadPow with basic exponentiation cases
     */
    function testWadMath_wadPow_basic() public {
        // x^0 = 1
        assertEq(WadMath.wadPow(2 * WAD, 0), WAD, "x^0 should equal 1");

        // x^1 = x
        assertEq(WadMath.wadPow(2 * WAD, 1), 2 * WAD, "x^1 should equal x");

        // 1^n = 1
        assertEq(WadMath.wadPow(WAD, 5), WAD, "1^n should equal 1");
    }

    /**
     * @notice Tests wadPow with small bases and various exponents
     */
    function testWadMath_wadPow_smallBase() public {
        uint smallBase = WAD / 2; // 0.5 in WAD

        // 0.5^2 = 0.25
        uint expected = WAD / 4; // 0.25 in WAD
        assertApproxEqAbs(WadMath.wadPow(smallBase, 2), expected, 1, "0.5^2 should equal 0.25");

        // 0.5^3 = 0.125
        expected = WAD / 8; // 0.125 in WAD
        assertApproxEqAbs(WadMath.wadPow(smallBase, 3), expected, 1, "0.5^3 should equal 0.125");
    }

    /**
     * @notice Tests wadPow with numbers greater than 1
     */
    function testWadMath_wadPow_largeBase() public {
        uint largeBase = 2 * WAD; // 2.0 in WAD

        // 2^2 = 4
        assertApproxEqAbs(WadMath.wadPow(largeBase, 2), 4 * WAD, 1, "2^2 should equal 4");

        // 2^3 = 8
        assertApproxEqAbs(WadMath.wadPow(largeBase, 3), 8 * WAD, 1, "2^3 should equal 8");
    }

    /**
     * @notice Tests wadPow with a sequence of increasing exponents
     */
    function testWadMath_wadPow_sequence() public {
        uint base = (3 * WAD) / 2; // 1.5 in WAD
        uint lastResult = WAD;

        // Test powers 1 through 5
        for (uint i = 1; i <= 5; i++) {
            uint result = WadMath.wadPow(base, i);
            assertTrue(result > lastResult, "Each power should be larger than the last");
            lastResult = result;
        }
    }

    /**
     * @notice Tests edge cases for wadPow
     */
    function testWadMath_wadPow_edgeCases() public {
        // Test with zero base
        assertEq(WadMath.wadPow(0, 5), 0, "0^n should equal 0 for n > 0");
        assertEq(WadMath.wadPow(0, 0), WAD, "0^0 should equal 1");

        // Test with large exponents
        uint largeExp = 10_000;
        uint smallBase = (WAD * 999) / 1000; // 0.999 in WAD
        uint result = WadMath.wadPow(smallBase, largeExp);
        assertTrue(result < WAD, "Small base raised to large power should decrease");
        assertTrue(result > 0, "Result should be greater than 0");
    }

    /**
     * @notice Tests large but realistic values for base and exponent
     */
    function testWadMath_wadPow_largeRealisticBaseAndExponent() public {
        // 500% annual rate per second (~1.000000585%)
        uint maxBase = WAD + (500 * WAD / 100 / 60 / 60 / 24 / 365);

        // 35% annual rate per second (~1.00000001098%)
        uint mediumBase = WAD + (35 * WAD / 100 / 60 / 60 / 24 / 365);

        // 1% annual rate per second (~1.000000000317098%)
        uint smallBase = WAD + (1 * WAD / 100 / 60 / 60 / 24 / 365);

        uint[] memory bases = new uint[](3);
        bases[0] = maxBase;
        bases[1] = mediumBase;
        bases[2] = smallBase;

        // 8 years in seconds (315360000 seconds)
        uint exponent = 8 * (60 * 60 * 24 * 365);

        for (uint i = 0; i < bases.length; i++) {
            WadMath.wadPow(bases[i], exponent);
        }
    }

    // External function to allow try-catch in gas benchmark
    function wadPowExternal(uint x, uint n) external pure returns (uint) {
        return WadMath.wadPow(x, n);
    }
}
