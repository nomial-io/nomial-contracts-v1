// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInventoryPool01} from "./interfaces/IInventoryPool01.sol";
import {IInventoryPoolParams01} from "./interfaces/IInventoryPoolParams01.sol";

/**
 * @dev ...
 * ...
 */
contract InventoryPoolParams01 is Ownable, IInventoryPoolParams01 {
    using Math for uint256;

    IInventoryPool01 private _inventoryPool;
    uint private _baseFee;
    uint private _baseRate;
    uint private _rate1;
    uint private _rate2;
    uint private _optimalUtilizationRate;
    uint private _penaltyRate;
    uint private _penaltyPeriod;

    constructor(
        address owner_,
        address inventoryPool_,
        bytes memory initData
    ) Ownable(owner_) {
        _inventoryPool = IInventoryPool01(inventoryPool_);

        (
            uint baseFee_,
            uint baseRate_,
            uint rate1_,
            uint rate2_,
            uint optimalUtilizationRate_,
            uint penaltyRate_,
            uint penaltyPeriod_
        ) = abi.decode(initData, (uint, uint, uint, uint, uint, uint, uint));

        _baseFee = baseFee_;
        _baseRate = baseRate_;
        _rate1 = rate1_;
        _rate2 = rate2_;
        _optimalUtilizationRate = optimalUtilizationRate_;
        _penaltyRate = penaltyRate_;
        _penaltyPeriod = penaltyPeriod_;
    }

    function inventoryPool() external view returns (address) {
        return address(_inventoryPool);
    }

    /* The initial fee for borrows. A fixed percentage expressed in 1e27 */
    function baseFee() external view returns (uint){
        return _baseFee;
    }

    /* Rate for interest on borrows. Rate is per-second expressed in 1e27. Based on Aave v3 formula for utilization-based variable interest rate */
    function interestRate() external view returns (uint interestRate_){
        uint utilizationRate_ = _inventoryPool.utilizationRate();
        if (utilizationRate_ <= _optimalUtilizationRate) {
            interestRate_ = _baseRate + utilizationRate_.mulDiv(1e27, _optimalUtilizationRate) * _rate1;
        } else {
            interestRate_ = _baseRate + _rate1 + (utilizationRate_ - _optimalUtilizationRate).mulDiv(1e27, (1e27 - _optimalUtilizationRate)) * _rate2;
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
