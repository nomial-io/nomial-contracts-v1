// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {IInventoryPoolParams01} from "./IInventoryPoolParams01.sol";

interface IInventoryPool01 {
    event Borrowed(address indexed borrower, address indexed recipient, uint amount);

    function borrow(uint amount, address borrower, address recipient, uint expiry, uint chainId) external;
    function repay(uint amount, address borrower) external;
    function absolvePenalty (address borrower) external;
    function upgrageParamsContract (address params_) external;

    function totalAssets() external view returns (uint);
    function totalReceivables() external view returns (uint);
    function utilizationRate() external view returns (uint);
    function baseDebt(address borrower) external view returns (uint);
    function penaltyDebt(address borrower) external view returns (uint);
    function penaltyTime(address borrower) external view returns (uint);
}
