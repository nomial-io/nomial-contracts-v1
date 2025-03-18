// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IInventoryPoolParams01 {
    error InvalidUtilizationRate(uint utilizationRate);

    function baseFee() external view returns (uint);
    function interestRate(uint utilizationRate_) external view returns (uint interestRate_);
    function penaltyRate() external view returns (uint);
    function penaltyPeriod() external view returns (uint);
}
