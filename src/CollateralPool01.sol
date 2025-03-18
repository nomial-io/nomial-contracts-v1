// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ICollateralPool01} from "./interfaces/ICollateralPool01.sol";

struct TokenWithdraw {
    IERC20 token;
    uint startTime;
    uint amount;
}

/**
 * @title CollateralPool01
 * @dev A contract for managing collateral deposits and withdrawals of multiple ERC20 tokens.
 * Features include:
 * - Deposit of any ERC20 token
 * - Time-locked withdrawals with configurable withdrawal period
 * - Balance and withdrawal liquidation by owner
 * The contract maintains separate balances for each depositor and token,
 * and implements a two-step withdrawal process to allow for time-locked withdrawals.
 */
contract CollateralPool01 is ICollateralPool01, Ownable, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    uint public withdrawPeriod;
    mapping(address => mapping(IERC20 => uint)) public tokenBalance;
    mapping(address => mapping(uint => TokenWithdraw)) public tokenWithdraws;
    mapping(address => uint) public withdrawNonce;

    /**
     * @notice Initializes the collateral pool with an owner and withdrawal period
     * @param owner The address that can liquidate balances and withdrawals
     * @param withdrawPeriod_ The time period (in seconds) that must elapse between requesting and executing a withdrawal
     */
    constructor(
        address owner,
        uint withdrawPeriod_
    ) Ownable(owner) {
        withdrawPeriod = withdrawPeriod_;
    }

    /**
     * @notice Deposits ERC20 tokens into the pool
     * @dev Transfers tokens from the sender to this contract and updates the sender's balance
     * @param token The ERC20 token to deposit
     * @param amount The amount of tokens to deposit
     * @custom:emits Deposited event with depositor address, token, and amount
     */
    function deposit(IERC20 token, uint amount) public nonReentrant() {
        tokenBalance[msg.sender][token] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount);
    }

    /**
     * @notice Initiates a withdrawal request for tokens
     * @dev Starts the withdrawal timer and moves tokens from balance to pending withdrawal
     * @param token The ERC20 token to withdraw
     * @param amount The amount of tokens to withdraw
     * @custom:emits WithdrawRequested event with details of the withdrawal request
     * @custom:revert InsufficientBalance if the depositor's balance is less than the requested amount
     */
    function startWithdraw(IERC20 token, uint amount) public nonReentrant() {
        if(tokenBalance[msg.sender][token] < amount) {
            revert InsufficientBalance(tokenBalance[msg.sender][token]);
        }

        if(amount == 0) {
            revert WithdrawAmountZero();
        }

        tokenBalance[msg.sender][token] -= amount;
        withdrawNonce[msg.sender] += 1;
        tokenWithdraws[msg.sender][withdrawNonce[msg.sender]] = TokenWithdraw(token, block.timestamp, amount);

        emit WithdrawRequested(msg.sender, withdrawNonce[msg.sender], block.timestamp, token, amount);
    }

    /**
     * @notice Completes a withdrawal request after the withdrawal period has elapsed
     * @dev Transfers tokens to the withdrawer if the withdrawal period has passed
     * @param nonce The identifier of the withdrawal request to process
     * @custom:emits WithdrawCompleted event upon successful withdrawal
     * @custom:revert NothingToWithdraw if the withdrawal request doesn't exist
     * @custom:revert WithdrawNotReady if the withdrawal period hasn't elapsed
     */
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

    /**
     * @notice Allows the owner to liquidate a depositor's token balance
     * @dev Transfers tokens from the depositor's balance to a specified recipient
     * @param depositor The address whose balance is being liquidated
     * @param token The ERC20 token to liquidate
     * @param amount The amount of tokens to liquidate
     * @param recipient The address that will receive the liquidated tokens
     * @custom:emits BalanceLiquidated event with liquidation details
     * @custom:revert InsufficientLiquidity if the depositor's balance is less than the liquidation amount
     */
    function liquidateBalance(address depositor, IERC20 token, uint amount, address recipient) public nonReentrant() onlyOwner() {
        if(tokenBalance[depositor][token] < amount) {
            revert InsufficientLiquidity(tokenBalance[depositor][token]);
        }

        tokenBalance[depositor][token] -= amount;
        token.safeTransfer(recipient, amount);

        emit BalanceLiquidated(depositor, token, amount, recipient);
    }

    /**
     * @notice Allows the owner to liquidate a pending withdrawal request
     * @dev Transfers tokens from a withdrawal request to a specified recipient
     * @param nonce The identifier of the withdrawal request to liquidate
     * @param depositor The address whose withdrawal is being liquidated
     * @param amount The amount of tokens to liquidate from the withdrawal
     * @param recipient The address that will receive the liquidated tokens
     * @custom:emits WithdrawLiquidated event with liquidation details
     * @custom:revert InsufficientLiquidity if the withdrawal amount is less than the liquidation amount
     */
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

    /**
     * @notice Updates the withdrawal period
     * @dev Can only be called by the owner
     * @param _withdrawPeriod The new withdrawal period in seconds
     * @custom:emits WithdrawPeriodUpdated event with the new period
     */
    function updateWithdrawPeriod(uint _withdrawPeriod) public onlyOwner() {
        withdrawPeriod = _withdrawPeriod;
        emit WithdrawPeriodUpdated(_withdrawPeriod);
    }

    /**
     * @notice Prevents accidental ETH transfers to the contract
     * @dev Reverts any ETH transfer to the contract
     * @custom:revert NotSupported for any ETH transfer
     */
    receive() external payable {
        revert NotSupported();
    }
}
