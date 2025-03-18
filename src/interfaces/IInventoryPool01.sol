// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IInventoryPool01 {
    event Borrowed(address indexed borrower, address indexed recipient, uint amount);
    event PenaltyRepayment(address indexed borrower, uint penaltyDebt, uint penaltyPaymentAmount);
    event BaseDebtRepayment(address indexed borrower, uint baseDebt, uint baseDebtPaymentAmount);

    error NotSupported();
    error Expired();
    error NoDebt();
    error ZeroRepayment();
    error InsufficientLiquidity();
    error WrongChainId();

    function borrow(uint amount, address borrower, address recipient, uint expiry, uint chainId) external;
    function repay(uint amount, address borrower) external;
    function upgrageParamsContract (address paramsContract) external;

    function totalAssets() external view returns (uint);
    function totalReceivables() external view returns (uint);
    function utilizationRate() external view returns (uint);
    function baseDebt(address borrower) external view returns (uint);
    function penaltyDebt(address borrower) external view returns (uint);
    function penaltyTime(address borrower) external view returns (uint);
}
