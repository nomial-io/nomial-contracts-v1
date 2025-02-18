// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {
    ICollateralPool01,
    InsufficientBalance,
    NothingToWithdraw,
    WithdrawNotReady,
    InsufficientLiquidity,
    NotSupported
} from "./interfaces/ICollateralPool01.sol";

struct TokenWithdraw {
    IERC20 token;
    uint startTime;
    uint amount;
}

/**
 * @dev ...
 * ...
 */
contract CollateralPool01 is ICollateralPool01, Ownable, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    uint public withdrawPeriod;
    mapping(address => mapping(IERC20 => uint)) public tokenBalance;
    mapping(address => mapping(uint => TokenWithdraw)) public tokenWithdraws;
    mapping(address => uint) public withdrawNonce;

    constructor(
        address owner,
        uint withdrawPeriod_
    ) Ownable(owner) {
        withdrawPeriod = withdrawPeriod_;
    }

    function deposit(IERC20 token, uint amount) public nonReentrant() {
        tokenBalance[msg.sender][token] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount);
    }

    function startWithdraw(IERC20 token, uint amount) public nonReentrant() {
        if(tokenBalance[msg.sender][token] < amount) {
            revert InsufficientBalance(tokenBalance[msg.sender][token]);
        }

        tokenBalance[msg.sender][token] -= amount;
        withdrawNonce[msg.sender] += 1;
        tokenWithdraws[msg.sender][withdrawNonce[msg.sender]] = TokenWithdraw(token, block.timestamp, amount);

        emit WithdrawRequested(msg.sender, withdrawNonce[msg.sender], block.timestamp, token, amount);
    }

    function withdraw(uint nonce) public nonReentrant() {
        TokenWithdraw storage _tokenWithdraw = tokenWithdraws[msg.sender][nonce];
        uint amount = _tokenWithdraw.amount;
        IERC20 token = _tokenWithdraw.token;

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        uint withdrawReadyTime = _tokenWithdraw.startTime + withdrawPeriod;
        if (withdrawReadyTime > block.timestamp) {
            revert WithdrawNotReady(withdrawReadyTime);
        }

        delete tokenWithdraws[msg.sender][nonce];
        token.safeTransfer(msg.sender, amount);

        emit WithdrawCompleted(msg.sender, nonce, token, amount);
    }

    function liquidateBalance(address depositor, IERC20 token, uint amount, address recipient) public nonReentrant() onlyOwner() {
        if(tokenBalance[depositor][token] < amount) {
            revert InsufficientLiquidity(tokenBalance[depositor][token]);
        }

        tokenBalance[depositor][token] -= amount;
        token.safeTransfer(recipient, amount);

        emit BalanceLiquidated(depositor, token, amount, recipient);
    }

    function liquidateWithdraw(uint nonce, address depositor, uint amount, address recipient) public nonReentrant() onlyOwner() {
        TokenWithdraw storage _tokenWithdraw = tokenWithdraws[depositor][nonce];
        if (_tokenWithdraw.amount < amount) {
            revert InsufficientLiquidity(_tokenWithdraw.amount);
        }

        IERC20 token = _tokenWithdraw.token;
        if (_tokenWithdraw.amount == amount) {
            delete tokenWithdraws[depositor][nonce];
        } else {
            _tokenWithdraw.amount -= amount;
        }
        token.safeTransfer(recipient, amount);

        emit WithdrawLiquidated(depositor, nonce, token, amount, recipient);
    }

    function updateWithdrawPeriod(uint _withdrawPeriod) public onlyOwner() {
        withdrawPeriod = _withdrawPeriod;
        emit WithdrawPeriodUpdated(_withdrawPeriod);
    }

    receive() external payable {
        revert NotSupported();
    }
}
