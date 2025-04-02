// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IInventoryPoolParams01} from "./interfaces/IInventoryPoolParams01.sol";

/**
 * @title OwnableParams01
 * @dev A parameter management contract for inventory pools that implements IInventoryPoolParams01
 * and inherits OpenZeppelin's Ownable for access control. This contract provides fixed parameters
 * that can be updated by the owner, including base fee, interest rate, penalty rate, and penalty period.
 * All rates are expressed in WAD (1e18) precision.
 */
contract OwnableParams01 is IInventoryPoolParams01, Ownable {
    /** @dev The base fee charged on new borrows, stored in WAD (1e18) precision */
    uint private _baseFee;

    /** @dev The fixed interest rate per second for loans, stored in WAD (1e18) precision */
    uint private _interestRate;

    /** @dev The penalty interest rate per second charged on overdue loans, stored in WAD (1e18) precision */
    uint private _penaltyRate;

    /** @dev The grace period before penalties apply (in seconds) */
    uint private _penaltyPeriod;

    /** @dev Emitted when the base fee is updated
     * @param oldBaseFee The previous base fee value
     * @param newBaseFee The new base fee value
     */
    event BaseFeeUpdated(uint oldBaseFee, uint newBaseFee);

    /** @dev Emitted when the interest rate is updated
     * @param oldInterestRate The previous interest rate value
     * @param newInterestRate The new interest rate value
     */
    event InterestRateUpdated(uint oldInterestRate, uint newInterestRate);

    /** @dev Emitted when the penalty rate is updated
     * @param oldPenaltyRate The previous penalty rate value
     * @param newPenaltyRate The new penalty rate value
     */
    event PenaltyRateUpdated(uint oldPenaltyRate, uint newPenaltyRate);

    /** @dev Emitted when the penalty period is updated
     * @param oldPenaltyPeriod The previous penalty period value
     * @param newPenaltyPeriod The new penalty period value
     */
    event PenaltyPeriodUpdated(uint oldPenaltyPeriod, uint newPenaltyPeriod);

    /**
     * @notice Initializes the contract with initial parameter values and owner
     * @dev Sets up all parameters and emits events for initial values
     * @param baseFee_ Initial base fee value, in WAD (1e18) precision
     * @param interestRate_ Initial interest rate value, in WAD (1e18) precision
     * @param penaltyRate_ Initial penalty rate value, in WAD (1e18) precision
     * @param penaltyPeriod_ Initial penalty period value, in seconds
     * @param owner Address that will be granted ownership of the contract
     */
    constructor(
        uint baseFee_,
        uint interestRate_,
        uint penaltyRate_,
        uint penaltyPeriod_,
        address owner
    ) Ownable(owner) {
        _baseFee = baseFee_;
        _interestRate = interestRate_;
        _penaltyRate = penaltyRate_;
        _penaltyPeriod = penaltyPeriod_;

        emit BaseFeeUpdated(0, baseFee_);
        emit InterestRateUpdated(0, interestRate_);
        emit PenaltyRateUpdated(0, penaltyRate_);
        emit PenaltyPeriodUpdated(0, penaltyPeriod_);
    }

    /**
     * @notice Returns the current base fee
     * @dev The base fee is charged upfront when a new borrow is created
     * @return The base fee value in WAD (1e18) precision
     */
    function baseFee() external view returns (uint) {
        return _baseFee;
    }

    /**
     * @notice Returns the current interest rate
     * @dev The interest rate accrues debt based on the time a borrower holds a loan
     * @param utilizationRate The utilization rate for the inventory pool (unused in this implementation)
     * @return The interest rate per second in WAD (1e18) precision
     */
    function interestRate(uint utilizationRate) external view returns (uint) {
        return _interestRate;
    }

    /**
     * @notice Returns the current penalty rate
     * @dev The penalty rate is added on top of the regular interest rate when a loan
     * exceeds the penalty period. Penalty rate is persecond in WAD (1e18) precision
     * @return The penalty rate per second in WAD (1e18) precision
     */
    function penaltyRate() external view returns (uint) {
        return _penaltyRate;
    }

    /**
     * @notice Returns the current penalty period
     * @dev The penalty period defines how many seconds a borrower has to repay their loan before
     * additional penalty interest starts accruing
     * @return The penalty period value in seconds
     */
    function penaltyPeriod() external view returns (uint) {
        return _penaltyPeriod;
    }

    /**
     * @notice Updates the base fee to a new value
     * @dev Only callable by the contract owner
     * @param newBaseFee The new base fee value in WAD (1e18) precision
     */
    function updateBaseFee(uint newBaseFee) external onlyOwner {
        emit BaseFeeUpdated(_baseFee, newBaseFee);
        _baseFee = newBaseFee;
    }

    /**
     * @notice Updates the interest rate to a new value
     * @dev Only callable by the contract owner
     * @param newInterestRate The new interest rate value in WAD (1e18) precision
     */
    function updateInterestRate(uint newInterestRate) external onlyOwner {
        emit InterestRateUpdated(_interestRate, newInterestRate);
        _interestRate = newInterestRate;
    }

    /**
     * @notice Updates the penalty rate to a new value
     * @dev Only callable by the contract owner
     * @param newPenaltyRate The new penalty rate value in WAD (1e18) precision
     */
    function updatePenaltyRate(uint newPenaltyRate) external onlyOwner {
        emit PenaltyRateUpdated(_penaltyRate, newPenaltyRate);
        _penaltyRate = newPenaltyRate;
    }

    /**
     * @notice Updates the penalty period to a new value
     * @dev Only callable by the contract owner
     * @param newPenaltyPeriod The new penalty period value in seconds
     */
    function updatePenaltyPeriod(uint newPenaltyPeriod) external onlyOwner {
        emit PenaltyPeriodUpdated(_penaltyPeriod, newPenaltyPeriod);
        _penaltyPeriod = newPenaltyPeriod;
    }
}
