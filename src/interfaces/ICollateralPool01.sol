// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error InsufficientBalance(uint balance);
error NothingToWithdraw();
error WithdrawNotReady(uint withdrawReadyTime);
error InsufficientLiquidity(uint amount);
error NotSupported();

interface ICollateralPool01 {
    event Deposited(address indexed depositor, IERC20 token, uint amount);
    event WithdrawRequested(address indexed depositor, uint nonce, uint startTime, IERC20 token, uint amount);
    event WithdrawCompleted(address indexed depositor, uint nonce, IERC20 token, uint amount);
    event WithdrawPeriodUpdated(uint withdrawPeriod);
    event BalanceLiquidated(address indexed depositor, IERC20 token, uint amount, address recipient);
    event WithdrawLiquidated(address indexed depositor, uint nonce, IERC20 token, uint amount, address recipient);

    function deposit(IERC20 token, uint amount) external;
    function startWithdraw(IERC20 token, uint amount) external;
    function withdraw(uint nonce) external;
    function liquidateBalance(address depositor, IERC20 token, uint amount, address recipient) external;
    function liquidateWithdraw(uint nonce, address depositor, uint amount, address recipient) external;
    function updateWithdrawPeriod(uint _withdrawPeriod) external;
    
    function withdrawPeriod() external view returns (uint);
    function tokenBalance(address depositor, IERC20 token) external view returns (uint);
    function tokenWithdraws(address depositor, uint nonce) external view returns (IERC20 token, uint startTime, uint amount);
    function withdrawNonce(address depositor) external view returns (uint);
} 