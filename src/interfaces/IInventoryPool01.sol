// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {IInventoryPoolParams01} from "./IInventoryPoolParams01.sol";

interface IInventoryPool01 {
    function borrow(uint amount, address borrower, address recipient, uint expiryTime) external;
    function repay(uint amount, address borrower) external;
    function setBorrowerDebt (uint scaledDebt, address borrower, uint penaltyCounterStart, uint penaltyDebtPaid) external;
    function setParamsContract (address params_) external;

    function totalAssets() external view returns (uint);
    function globalDebt() external view returns (uint);
    function baseDebt(address borrower) external view returns (uint);
    function penaltyDebt(address borrower) external view returns (uint);
    function penaltyTime(address borrower) external view returns (uint);
}
