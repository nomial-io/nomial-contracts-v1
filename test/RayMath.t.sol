// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RayMath} from "../src/utils/RayMath.sol";

contract RayMathTest is Test {
    uint constant RAY = 1e27;
    uint constant halfRAY = RAY / 2;

    /**
     * @notice Tests that ray() returns the correct RAY value
     */
    function testRayMath_ray() public {
        assertEq(RayMath.ray(), RAY, "ray() should return 1e27");
    }

    /**
     * @notice Tests that halfRay() returns the correct half RAY value
     */
    function testRayMath_halfRay() public {
        assertEq(RayMath.halfRay(), halfRAY, "halfRay() should return 5e26");
    }

    /**
     * @notice Tests rayMul with basic multiplication cases
     */
    function testRayMath_rayMul_basic() public {
        // 1 * 1 = 1
        assertEq(RayMath.rayMul(RAY, RAY), RAY, "1 * 1 should equal 1");

        // 2 * 0.5 = 1
        assertEq(RayMath.rayMul(2 * RAY, RAY / 2), RAY, "2 * 0.5 should equal 1");

        // 0 * 1 = 0
        assertEq(RayMath.rayMul(0, RAY), 0, "0 * 1 should equal 0");
    }

    /**
     * @notice Tests rayMul with small numbers
     */
    function testRayMath_rayMul_smallNumbers() public {
        // 0.1 * 0.1 = 0.01
        uint smallNum = RAY / 10; // 0.1 in RAY
        uint expected = RAY / 100; // 0.01 in RAY
        assertEq(RayMath.rayMul(smallNum, smallNum), expected, "0.1 * 0.1 should equal 0.01");
    }

    /**
     * @notice Tests rayMul with large numbers
     */
    function testRayMath_rayMul_largeNumbers() public {
        // Test with numbers close to uint256 max / 2
        uint largeNum = type(uint256).max / 3;
        uint result = RayMath.rayMul(largeNum, RAY);
        assertEq(result, largeNum, "Large number * 1 should equal the large number");
    }

    /**
     * @notice Tests rayPow with basic exponentiation cases
     */
    function testRayMath_rayPow_basic() public {
        // x^0 = 1
        assertEq(RayMath.rayPow(2 * RAY, 0), RAY, "x^0 should equal 1");

        // x^1 = x
        assertEq(RayMath.rayPow(2 * RAY, 1), 2 * RAY, "x^1 should equal x");

        // 1^n = 1
        assertEq(RayMath.rayPow(RAY, 5), RAY, "1^n should equal 1");
    }

    /**
     * @notice Tests rayPow with small bases and various exponents
     */
    function testRayMath_rayPow_smallBase() public {
        uint smallBase = RAY / 2; // 0.5 in RAY

        // 0.5^2 = 0.25
        uint expected = RAY / 4; // 0.25 in RAY
        assertApproxEqAbs(RayMath.rayPow(smallBase, 2), expected, 1, "0.5^2 should equal 0.25");

        // 0.5^3 = 0.125
        expected = RAY / 8; // 0.125 in RAY
        assertApproxEqAbs(RayMath.rayPow(smallBase, 3), expected, 1, "0.5^3 should equal 0.125");
    }

    /**
     * @notice Tests rayPow with numbers greater than 1
     */
    function testRayMath_rayPow_largeBase() public {
        uint largeBase = 2 * RAY; // 2.0 in RAY

        // 2^2 = 4
        assertApproxEqAbs(RayMath.rayPow(largeBase, 2), 4 * RAY, 1, "2^2 should equal 4");

        // 2^3 = 8
        assertApproxEqAbs(RayMath.rayPow(largeBase, 3), 8 * RAY, 1, "2^3 should equal 8");
    }

    /**
     * @notice Tests rayPow with a sequence of increasing exponents
     */
    function testRayMath_rayPow_sequence() public {
        uint base = (3 * RAY) / 2; // 1.5 in RAY
        uint lastResult = RAY;

        // Test powers 1 through 5
        for (uint i = 1; i <= 5; i++) {
            uint result = RayMath.rayPow(base, i);
            assertTrue(result > lastResult, "Each power should be larger than the last");
            lastResult = result;
        }
    }

    /**
     * @notice Tests edge cases for rayMul
     */
    function testRayMath_rayMul_edgeCases() public {
        // Test with max uint256 value
        uint maxUint = type(uint256).max;
        vm.expectRevert();
        RayMath.rayMul(maxUint, maxUint);

        // Test with values that would cause overflow without scaling
        uint largeButSafe = type(uint256).max / RAY;
        uint result = RayMath.rayMul(largeButSafe, RAY);
        assertEq(result, largeButSafe, "Large but safe multiplication should work");
    }

    /**
     * @notice Tests edge cases for rayPow
     */
    function testRayMath_rayPow_edgeCases() public {
        // Test with zero base
        assertEq(RayMath.rayPow(0, 5), 0, "0^n should equal 0 for n > 0");
        assertEq(RayMath.rayPow(0, 0), RAY, "0^0 should equal 1");

        // Test with large exponents
        uint largeExp = 1_000_000;
        uint smallBase = (RAY * 999) / 1000; // 0.999 in RAY
        uint result = RayMath.rayPow(smallBase, largeExp);
        assertTrue(result < RAY, "Small base raised to large power should decrease");
        assertTrue(result > 0, "Result should be greater than 0");
    }

    /**
     * @notice Benchmarks gas costs for rayPow with different exponents
     */
    function testRayMath_rayPow_gasBenchmark() public {
        uint base = (3 * RAY) / 2; // 1.5 in RAY

        // Benchmark exponents 1 through 10
        for (uint i = 1; i <= 10; i++) {
            uint gasBefore = gasleft();
            RayMath.rayPow(base, i);
            uint gasUsed = gasBefore - gasleft();
            emit log_named_uint(string.concat("Gas used for rayPow(1.5, ", vm.toString(i), ")"), gasUsed);
        }

        // Benchmark exponent 1_000_000
        uint gasBefore = gasleft();
        uint smallBase = (RAY * 999) / 1000; // 0.999 in RAY
        RayMath.rayPow(smallBase, 1_000_000);
        uint gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for rayPow(0.999, 1_000_000)", gasUsed);
    }

    /**
     * @notice Benchmarks gas costs for rayPow with different bases
     */
    function testRayMath_rayPow_gasBenchmarkBases() public {
        uint[] memory bases = new uint[](5);
        bases[0] = RAY / 2;     // 0.5
        bases[1] = RAY;         // 1.0
        bases[2] = 2 * RAY;     // 2.0
        bases[3] = 10 * RAY;    // 10.0
        bases[4] = 100 * RAY;   // 100.0

        uint exponent = 5;  // Fixed exponent for comparison

        for (uint i = 0; i < bases.length; i++) {
            uint gasBefore = gasleft();
            RayMath.rayPow(bases[i], exponent);
            uint gasUsed = gasBefore - gasleft();
            emit log_named_uint(
                string.concat(
                    "Gas used for rayPow(",
                    vm.toString(bases[i] / RAY),
                    ".0, 5)"
                ),
                gasUsed
            );
        }
    }

    /**
     * @notice Benchmarks gas costs for rayPow with edge cases
     */
    function testRayMath_rayPow_gasBenchmarkEdgeCases() public {
        // Test edge cases
        uint[] memory bases = new uint[](4);
        uint[] memory exponents = new uint[](4);
        string[] memory labels = new string[](4);

        // Edge cases setup
        bases[0] = 0;               labels[0] = "0";     exponents[0] = 5;
        bases[1] = type(uint).max;  labels[1] = "max";   exponents[1] = 1;
        bases[2] = RAY - 1;         labels[2] = "1-eps"; exponents[2] = 10;
        bases[3] = RAY + 1;         labels[3] = "1+eps"; exponents[3] = 10;

        for (uint i = 0; i < bases.length; i++) {
            uint gasBefore = gasleft();
            
            // Some combinations might revert, so we use try-catch
            try this.rayPowExternal(bases[i], exponents[i]) {
                uint gasUsed = gasBefore - gasleft();
                emit log_named_uint(
                    string.concat(
                        "Gas used for rayPow(",
                        labels[i],
                        ", ",
                        vm.toString(exponents[i]),
                        ")"
                    ),
                    gasUsed
                );
            } catch {
                emit log_named_string(
                    string.concat(
                        "rayPow(",
                        labels[i],
                        ", ",
                        vm.toString(exponents[i]),
                        ")"
                    ),
                    "reverted"
                );
            }
        }
    }

    // External function to allow try-catch in gas benchmark
    function rayPowExternal(uint x, uint n) external pure returns (uint) {
        return RayMath.rayPow(x, n);
    }
}
