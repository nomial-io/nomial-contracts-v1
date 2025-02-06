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
    uint private _interestRate;
    uint private _penaltyRate;
    uint private _penaltyPeriod;

    constructor(
        address owner_,
        IInventoryPool01 inventoryPool_,
        uint baseFee_,
        uint interestRate_,
        uint penaltyRate_,
        uint penaltyPeriod_
    ) Ownable(owner_) {
        _inventoryPool = inventoryPool_;
        _baseFee = baseFee_;
        _interestRate = interestRate_;
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

    /* Rate for interest on borrows. Rate is per-second expressed in 1e27 */
    function interestRate() external view returns (uint){
        return _interestRate;
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
