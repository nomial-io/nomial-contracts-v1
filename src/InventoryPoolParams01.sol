// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInventoryPoolParams01, InvalidUtilizationRate} from "./interfaces/IInventoryPoolParams01.sol";

/**
 * @dev ...
 * ...
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

    /* The initial fee for borrows. A fixed percentage expressed in 1e27 */
    function baseFee() external view returns (uint){
        return _baseFee;
    }

    /* Rate for interest on borrows. Rate is per-second expressed in 1e27. Based on Aave v3 formula for utilization-based variable interest rate */
    function interestRate(uint utilizationRate_) external view returns (uint interestRate_){
        if (utilizationRate_ > 1e27) revert InvalidUtilizationRate();

        if (utilizationRate_ <= _optimalUtilizationRate) {
            interestRate_ = _baseRate + _rate1.mulDiv(utilizationRate_, _optimalUtilizationRate);
        } else {
            interestRate_ = _baseRate + _rate1 + _rate2.mulDiv((utilizationRate_ - _optimalUtilizationRate), (1e27 - _optimalUtilizationRate));
        }
    }

    /* Rate for interest after penalty period. Penalty rate is in addition to interest rate. Rate is per-second expressed in 1e27 */
    function penaltyRate() external view returns (uint){
        return _penaltyRate;
    }

    /* Number of seconds before penalty interest rate is applied */
    function penaltyPeriod() external view returns (uint){
        return _penaltyPeriod;
    }
}
