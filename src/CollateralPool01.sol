// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ICollateralPool01} from "./interfaces/ICollateralPool01.sol";

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

    /**
     * @dev Represents a pending withdrawal request
     * @param token The ERC20 token being withdrawn
     * @param startTime The timestamp when the withdrawal request was initiated
     * @param amount The amount of tokens requested for withdrawal
     */
    struct TokenWithdraw {
        IERC20 token;
        uint startTime;
        uint amount;
    }

    /**
     * @dev Stores a depositor's token balances, withdrawal requests, and withdrawal nonce
     * @param tokenBalance Stores a depositor's token balances
     * @param tokenWithdraws Stores a depositor's withdrawal requests
     * @param withdrawNonce A unique identifier that increments when the depositor makes a new withdrawal request
     */
    struct Depositor {
        mapping(IERC20 => uint) tokenBalance;
        mapping(uint => TokenWithdraw) tokenWithdraws;
        uint withdrawNonce;
    }

    /// @notice The time period (in seconds) that must elapse between requesting and executing a withdrawal
    uint public withdrawPeriod;

    /// @dev Internal mapping to store depositor data
    mapping(address => Depositor) internal depositors;

    /**
     * @notice Initializes the collateral pool with an owner and withdrawal period
     * @param owner The address that can liquidate balances and withdrawals
     * @param initialWithdrawPeriod The time period (in seconds) that must elapse between requesting and executing a withdrawal
     */
    constructor(
        address owner,
        uint initialWithdrawPeriod
    ) Ownable(owner) {
        withdrawPeriod = initialWithdrawPeriod;

        emit WithdrawPeriodUpdated(initialWithdrawPeriod);
    }

    /**
     * @notice Deposits ERC20 tokens into the pool
     * @dev Transfers tokens from the sender to this contract and updates the sender's balance
     * @param token The ERC20 token to deposit
     * @param amount The amount of tokens to deposit
     * @custom:emits Deposited event with depositor address, token, and amount
     */
    function deposit(IERC20 token, uint amount) public nonReentrant() {
        depositors[msg.sender].tokenBalance[token] += amount;
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
        Depositor storage _depositor = depositors[msg.sender];
        uint _balance = _depositor.tokenBalance[token];
        if(_balance < amount) {
            revert InsufficientBalance(_balance);
        }

        if(amount == 0) {
            revert WithdrawAmountZero();
        }

        _depositor.tokenBalance[token] -= amount;
        _depositor.withdrawNonce += 1;
        uint _withdrawNonce = _depositor.withdrawNonce;
        _depositor.tokenWithdraws[_withdrawNonce] = TokenWithdraw(token, block.timestamp, amount);

        emit WithdrawRequested(msg.sender, _withdrawNonce, block.timestamp, token, amount);
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
        Depositor storage _depositor = depositors[msg.sender];
        TokenWithdraw storage _tokenWithdraw = _depositor.tokenWithdraws[nonce];
        uint amount = _tokenWithdraw.amount;
        IERC20 token = _tokenWithdraw.token;

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        uint withdrawReadyTime = _tokenWithdraw.startTime + withdrawPeriod;
        if (withdrawReadyTime > block.timestamp) {
            revert WithdrawNotReady(withdrawReadyTime);
        }

        delete _depositor.tokenWithdraws[nonce];
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
        Depositor storage _depositor = depositors[depositor];
        uint _balance = _depositor.tokenBalance[token];
        if(_balance < amount) {
            revert InsufficientLiquidity(_balance);
        }

        _depositor.tokenBalance[token] -= amount;
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
        Depositor storage _depositor = depositors[depositor];
        TokenWithdraw storage _tokenWithdraw = _depositor.tokenWithdraws[nonce];
        uint _withdrawAmount = _tokenWithdraw.amount;
        if (_withdrawAmount < amount) {
            revert InsufficientLiquidity(_withdrawAmount);
        }

        IERC20 token = _tokenWithdraw.token;
        if (_withdrawAmount == amount) {
            delete _depositor.tokenWithdraws[nonce];
        } else {
            _tokenWithdraw.amount -= amount;
        }
        token.safeTransfer(recipient, amount);

        emit WithdrawLiquidated(depositor, nonce, token, amount, recipient);
    }

    /**
     * @notice Updates the withdrawal period
     * @dev Can only be called by the owner
     * @param newWithdrawPeriod The new withdrawal period in seconds
     * @custom:emits WithdrawPeriodUpdated event with the new period
     */
    function updateWithdrawPeriod(uint newWithdrawPeriod) public onlyOwner() {
        if (withdrawPeriod == newWithdrawPeriod) {
            revert PeriodNotChanged();
        }

        withdrawPeriod = newWithdrawPeriod;

        emit WithdrawPeriodUpdated(newWithdrawPeriod);
    }

    /**
     * @notice Returns the depositor's balance of a token
     * @dev Retrieves the current balance of a token from the depositors mapping
     * @param depositor The depositor's address
     * @param token The ERC20 token address
     * @return The depositor's balance of the token
     */
    function tokenBalance(address depositor, IERC20 token) public view returns (uint) {
        return depositors[depositor].tokenBalance[token];
    }

    /**
     * @notice Returns the details of a specific withdrawal request made by a depositor
     * @dev Retrieves the token, start time, and amount for a given depositor and withdrawal nonce
     * @param depositor The depositor's address
     * @param nonce Unique identifier of the withdrawal request
     * @return token The ERC20 token being withdrawn
     * @return startTime The timestamp when the withdrawal request was initiated
     * @return amount The amount of tokens requested for withdrawal
     */
    function tokenWithdraws(address depositor, uint nonce) public view returns (IERC20 token, uint startTime, uint amount) {
        TokenWithdraw memory _tokenWithdraw = depositors[depositor].tokenWithdraws[nonce];
        return (_tokenWithdraw.token, _tokenWithdraw.startTime, _tokenWithdraw.amount);
    }

    /**
     * @notice Returns the current withdrawal nonce for a depositor
     * @dev This nonce starts at 0 and increments with each new withdrawal request
     * @param depositor The depositor's address
     * @return The current withdrawal nonce for the depositor
     */
    function withdrawNonce(address depositor) public view returns (uint) {
        return depositors[depositor].withdrawNonce;
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
