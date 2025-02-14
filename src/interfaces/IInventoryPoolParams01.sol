// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {IInventoryPool01} from "./IInventoryPool01.sol";

interface IInventoryPoolParams01 {
    function baseFee() external view returns (uint);
    function interestRate(uint utilizationRate_) external view returns (uint);
    function penaltyRate() external view returns (uint);
    function penaltyPeriod() external view returns (uint);
}
