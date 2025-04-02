// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInventoryPoolParams01} from "./interfaces/IInventoryPoolParams01.sol";

/**
 * @title UtilizationBasedRateParams01
 * @dev Manages the parameters for an InventoryPool using a utilization-based interest rate model
 * similar to Aave v3, where the interest rate increases as utilization increases
 * (See https://aave.com/docs/developers/smart-contracts/interest-rate-strategy).
 * All rates are expressed in WAD (1e18) precision.
 */
contract UtilizationBasedRateParams01 is Ownable, IInventoryPoolParams01 {
    using Math for uint256;

    uint constant WAD = 1e18;

    /// @notice The base fee charged on new borrows. Expressed as a percentage in WAD (1e18) precision.
    /// @dev This fee is charged upfront when a new borrow is created and is added to the scaled debt
    uint private _baseFee;

    /// @notice The base interest rate per second. Expressed as a percentage in WAD (1e18) precision.
    /// @dev This is the minimum interest rate charged regardless of utilization
    uint private _baseRate;

    /// @notice The slope of the interest rate curve below optimal utilization. Expressed in WAD (1e18) precision.
    /// @dev Used to calculate interest rate between 0% and optimal utilization
    uint private _rate1;

    /// @notice The slope of the interest rate curve above optimal utilization. Expressed in WAD (1e18) precision.
    /// @dev Used to calculate interest rate between optimal and 100% utilization
    uint private _rate2;

    /// @notice The optimal utilization rate target. Expressed as a percentage in WAD (1e18) precision.
    /// @dev The point at which the interest rate curve switches from rate1 to rate2 slope
    uint private _optimalUtilizationRate;

    /// @notice The penalty interest rate per second. Expressed as a percentage in WAD (1e18) precision.
    /// @dev Added on top of the utilization-based interest rate
    uint private _penaltyRate;

    /// @notice The duration in seconds before penalty interest starts accruing.
    /// @dev Used to incentivize repayment of loans within the penalty period
    uint private _penaltyPeriod;

    /// @notice Emitted when the parameters are updated
    event ParamsUpdated(
        uint baseFee,
        uint baseRate,
        uint rate1,
        uint rate2,
        uint optimalUtilizationRate,
        uint penaltyRate,
        uint penaltyPeriod
    );

    /**
     * @notice Initializes the parameters contract with interest rate model settings
     * @dev All rate parameters should be in WAD (1e18) precision
     * @param owner_ The address that will own this contract
     * @param baseFee_ The upfront fee charged on new borrows
     * @param baseRate_ The minimum interest rate per second
     * @param rate1_ The interest rate slope below optimal utilization
     * @param rate2_ The interest rate slope above optimal utilization
     * @param optimalUtilizationRate The target utilization rate where slope changes
     * @param penaltyRate_ The additional interest rate for overdue loans
     * @param penaltyPeriod_ The duration in seconds before penalty rate applies
     */
    constructor(
        address owner_,
        uint baseFee_,
        uint baseRate_,
        uint rate1_,
        uint rate2_,
        uint optimalUtilizationRate,
        uint penaltyRate_,
        uint penaltyPeriod_
    ) Ownable(owner_) {
        _baseFee = baseFee_;
        _baseRate = baseRate_;
        _rate1 = rate1_;
        _rate2 = rate2_;
        _optimalUtilizationRate = optimalUtilizationRate;
        _penaltyRate = penaltyRate_;
        _penaltyPeriod = penaltyPeriod_;

        emit ParamsUpdated(baseFee_, baseRate_, rate1_, rate2_, optimalUtilizationRate, penaltyRate_, penaltyPeriod_);
    }

    /**
     * @notice Returns the base fee charged on new borrows
     * @dev The base fee is a fixed percentage expressed in WAD (1e18) precision that is charged
     * upfront when a new borrow is created
     * @return The base fee as a percentage in WAD (1e18) precision
     */
    function baseFee() external view returns (uint) {
        return _baseFee;
    }

    /**
     * @notice Calculates the interest rate based on the current utilization rate
     * @dev Uses a two-slope model similar to Aave v3:
     * - Below optimal: rate = baseRate + (rate1 * utilization / optimalUtilization)
     * - Above optimal: rate = baseRate + rate1 + (rate2 * (utilization - optimal) / (1 - optimal))
     * All rates are per-second and expressed in WAD (1e18) precision
     * @param utilizationRate The current utilization rate in WAD (1e18) precision
     * @return interestRate The calculated interest rate per second in WAD (1e18) precision
     * @custom:revert InvalidUtilizationRate If utilization rate exceeds 100%
     */
    function interestRate(uint utilizationRate) external view returns (uint) {
        if (utilizationRate > WAD) revert InvalidUtilizationRate(utilizationRate);

        if (utilizationRate <= _optimalUtilizationRate) {
            return _baseRate + _rate1.mulDiv(utilizationRate, _optimalUtilizationRate);
        } else {
            return _baseRate + _rate1 + _rate2.mulDiv((utilizationRate - _optimalUtilizationRate), (WAD - _optimalUtilizationRate));
        }
    }

    /**
     * @notice Returns the penalty interest rate applied after the penalty period
     * @dev The penalty rate is added on top of the regular interest rate when a loan
     * exceeds its penalty period. Rate is per-second in WAD (1e18) precision
     * @return The penalty rate per second in WAD (1e18) precision
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

    /**
     * @notice Updates the parameters for the utilization-based interest rate model
     * @dev Only the owner can update the parameters
     * @param baseFee_ The base fee charged on new borrows
     * @param baseRate_ The base interest rate per second
     * @param rate1_ The slope of the interest rate curve below optimal utilization
     * @param rate2_ The slope of the interest rate curve above optimal utilization
     * @param optimalUtilizationRate The optimal utilization rate target
     * @param penaltyRate_ The penalty interest rate per second
     * @param penaltyPeriod_ The duration in seconds before penalty interest starts accruing
     */
    function updateParams(uint baseFee_, uint baseRate_, uint rate1_, uint rate2_, uint optimalUtilizationRate, uint penaltyRate_, uint penaltyPeriod_) external onlyOwner {
        _baseFee = baseFee_;
        _baseRate = baseRate_;
        _rate1 = rate1_;
        _rate2 = rate2_;
        _optimalUtilizationRate = optimalUtilizationRate;
        _penaltyRate = penaltyRate_;
        _penaltyPeriod = penaltyPeriod_;

        emit ParamsUpdated(baseFee_, baseRate_, rate1_, rate2_, optimalUtilizationRate, penaltyRate_, penaltyPeriod_);
    }
}
