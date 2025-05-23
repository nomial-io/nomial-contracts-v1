// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Helper is Test {
    uint256 public BLOCK_JAN_16_2025 = 21_638_600;

    uint public TEST_TIMESTAMP = 1739393780;

    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public ST_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    IERC20 public WETH_ERC20 = IERC20(WETH);
    IERC20 public USDC_ERC20 = IERC20(USDC);
    IERC20 public ST_ETH_ERC20 = IERC20(ST_ETH);

    address public ETH_WHALE = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address public WETH_WHALE = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public USDC_WHALE = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
    address public ST_ETH_WHALE = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;

    address public DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    uint public MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // 1 bps (0.01 %)
    uint public defaultBaseFee = 1 * 1e14;

    // utilization-based interest rate params, modeled from Aave V3's USDC pool

    // 0% base rate
    uint public defaultBaseRate = 0;

    // 10% annual rate1 (per-second)
    // 10n * 10n**16n / (60n * 60n * 24n * 365n)
    uint public defaultRate1 = 3170979198;

    // 100% annual rate2 (per-second)
    // 100n * 10n**16n / (60n * 60n * 24n * 365n)
    uint public defaultRate2 = 31709791983;

    // 80% optimal utilization rate
    // 80n * 10n**16n
    uint public defaultOptimalUtilizationRate = 800000000000000000;

    // 500% annual penalty rate, per second
    // 500n * 10n**16n / (60n * 60n * 24n * 365n)
    uint public defaultPenaltyRate = 158548959918;

    // 24 hour penalty period, in seconds
    uint public defaultPenaltyPeriod = 86400;

    function setupAll () public {
        setupFork(BLOCK_JAN_16_2025);
    }
    
    function setupFork (uint blockNumber) public {
        uint fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), blockNumber);
        vm.selectFork(fork);
    }

    // Helper function to get signatures from specific private keys
    function getSignaturesFromKeys(bytes32 digest, uint256[] memory privKeys) public pure returns (bytes[] memory) {
        bytes[] memory signatures = new bytes[](privKeys.length);
        for (uint i = 0; i < privKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKeys[i], digest);
            signatures[i] = abi.encodePacked(r, s, v);
        }
        return signatures;
    }
}
