// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Helper is Test {

    uint256 public BLOCK_JAN_16_2025 = 21_638_600;

    uint public TEST_TIMESTAMP = 1739393780;

    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 public WETH_ERC20 = IERC20(WETH);
    IERC20 public USDC_ERC20 = IERC20(USDC);

    address public ETH_WHALE = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address public WETH_WHALE = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public USDC_WHALE = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
    
    uint public MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // 1 bps (0.01 %)
    uint public defaultBaseFee = 1 * 1e23;

    // utilization-based interest rate params, modeled from Aave V3's USDC pool

    // 0% base rate
    uint public defaultBaseRate = 0;

    // 11.5% annual rate1 (per-second)
    // 115 * 1e24 / (60 * 60 * 24 * 365)
    uint public defaultRate1 = 3646626078132927500;

    // 46.5% annual rate2 (per-second)
    // 465 * 1e24 / (60 * 60 * 24 * 365)
    uint public defaultRate2 = 14745053272450533000;

    // 92% optimal utilization rate
    // 92 * 1e25
    uint public defaultOptimalUtilizationRate = 920000000000000000000000000;

    // 500% annual penalty rate, per second
    // 500 * 1e25 / (60 * 60 * 24 * 365)
    uint public defaultPenaltyRate = 158548959918822932521;

    // 24 hour penalty period, in seconds
    uint public defaultPenaltyPeriod = 86400;

    function setupAll () public {
        setupFork(BLOCK_JAN_16_2025);
    }
    
    function setupFork (uint blockNumber) public {
        uint fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), blockNumber);
        vm.selectFork(fork);
    }

}
