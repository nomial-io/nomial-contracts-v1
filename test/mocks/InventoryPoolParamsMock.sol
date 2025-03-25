// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IInventoryPoolParams01} from "../../src/interfaces/IInventoryPoolParams01.sol";

contract InventoryPoolParamsMock is IInventoryPoolParams01 {
    uint private immutable _baseFee;
    uint private immutable _interestRate;
    uint private immutable _penaltyRate;
    uint private immutable _penaltyPeriod;

    constructor(
        uint baseFee_,
        uint interestRate_,
        uint penaltyRate_,
        uint penaltyPeriod_
    ) {
        _baseFee = baseFee_;
        _interestRate = interestRate_;
        _penaltyRate = penaltyRate_;
        _penaltyPeriod = penaltyPeriod_;
    }

    function baseFee() external view returns (uint) {
        return _baseFee;
    }

    function interestRate(uint utilizationRate) external view returns (uint) {
        return _interestRate;
    }

    function penaltyRate() external view returns (uint) {
        return _penaltyRate;
    }

    function penaltyPeriod() external view returns (uint) {
        return _penaltyPeriod;
    }
}
