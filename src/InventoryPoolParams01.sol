// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInventoryPoolParams01} from "./interfaces/IInventoryPoolParams01.sol";

/**
 * @title InventoryPoolParams01
 * @dev Manages the parameters for an InventoryPool. Uses a utilization-based interest rate model
 * similar to Aave v3, where the interest rate increases as utilization increases.
 * All rates are expressed in 1e27 precision.
 */
contract InventoryPoolParams01 is Ownable, IInventoryPoolParams01 {
    using Math for uint256;

    uint private _baseFee;
    uint private _baseRate;
    uint private _rate1;
    uint private _rate2;
    uint private _optimalUtilizationRate;
    uint private _penaltyRate;
    uint private _penaltyPeriod;

    constructor(
        address owner_,
        uint baseFee_,
        uint baseRate_,
        uint rate1_,
        uint rate2_,
        uint optimalUtilizationRate_,
        uint penaltyRate_,
        uint penaltyPeriod_
    ) Ownable(owner_) {
        _baseFee = baseFee_;
        _baseRate = baseRate_;
        _rate1 = rate1_;
        _rate2 = rate2_;
        _optimalUtilizationRate = optimalUtilizationRate_;
        _penaltyRate = penaltyRate_;
        _penaltyPeriod = penaltyPeriod_;
    }

    /**
     * @notice Returns the base fee charged on new borrows
     * @dev The base fee is a fixed percentage expressed in 1e27 precision that is charged
     * upfront when a new borrow is created
     * @return The base fee as a percentage in 1e27 precision
     */
    function baseFee() external view returns (uint) {
        return _baseFee;
    }

    /**
     * @notice Calculates the interest rate based on the current utilization rate
     * @dev Uses a two-slope model similar to Aave v3:
     * - Below optimal: rate = baseRate + (rate1 * utilization / optimalUtilization)
     * - Above optimal: rate = baseRate + rate1 + (rate2 * (utilization - optimal) / (1 - optimal))
     * All rates are per-second and expressed in 1e27 precision
     * @param utilizationRate_ The current utilization rate in 1e27 precision
     * @return interestRate_ The calculated interest rate per second in 1e27 precision
     * @custom:revert InvalidUtilizationRate If utilization rate exceeds 100% (1e27)
     */
    function interestRate(uint utilizationRate_) external view returns (uint interestRate_) {
        if (utilizationRate_ > 1e27) revert InvalidUtilizationRate(utilizationRate_);

        if (utilizationRate_ <= _optimalUtilizationRate) {
            interestRate_ = _baseRate + _rate1.mulDiv(utilizationRate_, _optimalUtilizationRate);
        } else {
            interestRate_ = _baseRate + _rate1 + _rate2.mulDiv((utilizationRate_ - _optimalUtilizationRate), (1e27 - _optimalUtilizationRate));
        }
    }

    /**
     * @notice Returns the penalty interest rate applied after the penalty period
     * @dev The penalty rate is added on top of the regular interest rate when a loan
     * exceeds its penalty period. Rate is per-second in 1e27 precision
     * @return The penalty rate per second in 1e27 precision
     */
    function penaltyRate() external view returns (uint) {
        return _penaltyRate;
    }

    /**
     * @notice Returns the duration before penalty interest starts accruing
     * @dev The penalty period defines how long a borrower has to repay before
     * additional penalty interest starts accruing
     * @return The penalty period in seconds
     */
    function penaltyPeriod() external view returns (uint) {
        return _penaltyPeriod;
    }
}
