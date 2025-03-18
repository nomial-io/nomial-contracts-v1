// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC4626, IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IInventoryPool01,
    NotSupported,
    Expired,
    NoDebt,
    ZeroRepayment,
    InsufficientLiquidity,
    WrongChainId
} from "./interfaces/IInventoryPool01.sol";
import {IInventoryPoolParams01} from "./interfaces/IInventoryPoolParams01.sol";

struct BorrowerData {
    uint scaledDebt;
    uint penaltyCounterStart;
    uint partialPenaltyPayment;
}

/**
 * @title InventoryPool01
 * @dev An ERC4626-compliant lending pool that allows borrowing by the pool owner and tracks debt
 * Features include:
 * - Variable interest rates based on pool utilization
 * - Penalty interest for overdue loans
 * - Repayment of both base debt and penalty debt
 * All rates and calculations use 1e27 precision for accurate interest accrual
 */
contract InventoryPool01 is ERC4626, Ownable, IInventoryPool01, ReentrancyGuardTransient {
    using Math for uint256;
    using SafeERC20 for IERC20;

    IInventoryPoolParams01 public params;
    uint public storedAccInterestFactor;
    uint public lastAccumulatedInterestUpdate;
    uint public scaledReceivables;

    mapping(address => BorrowerData) public borrowers;

    constructor(
        IERC20 asset_,
        string memory name,
        string memory symbol,
        uint initAmount,
        address owner,
        address paramsContract
    ) ERC4626(IERC20(asset_)) ERC20(name, symbol) Ownable(owner) {
        /**
         * deployer is responsible for burning a small deposit to mitigate inflation attack.
         * this ERC4626 implementation uses offset to make inflation attack un-profitable
         * but burning a small initial deposit eliminates the possibility of a griefing attack
         */
        deposit(initAmount, 0x000000000000000000000000000000000000dEaD);

        params = IInventoryPoolParams01(paramsContract);
    }

    /**
     * @notice Creates a new borrow position
     * @dev Only callable by owner. Creates a new borrow position with the specified amount
     * and transfers the borrowed assets to the recipient. Interest starts accruing immediately.
     * @param amount The amount of assets to borrow
     * @param borrower The address that will own the debt position
     * @param recipient The address that will receive the borrowed assets
     * @param expiry The timestamp after which this borrow request is no longer valid
     * @param chainId The chain ID where this borrow should be executed (for cross-chain safety)
     * @custom:revert Expired If the current timestamp is past the expiry
     * @custom:revert WrongChainId If executed on a different chain than specified
     */
    function borrow(uint amount, address borrower, address recipient, uint expiry, uint chainId) external nonReentrant() onlyOwner() {
        if (block.timestamp > expiry) revert Expired();
        if (block.chainid != chainId) revert WrongChainId();

        _updateAccumulatedInterestFactor();

        uint scaledDebt_ = amount.mulDiv(1e27, storedAccInterestFactor, Math.Rounding.Ceil) + amount.mulDiv(params.baseFee(), 1e27, Math.Rounding.Ceil);
        borrowers[borrower].scaledDebt += scaledDebt_;
        scaledReceivables += scaledDebt_;
        if (borrowers[borrower].penaltyCounterStart == 0) {
            borrowers[borrower].penaltyCounterStart = block.timestamp;
        }

        IERC20(asset()).safeTransfer(recipient, amount);

        emit Borrowed(borrower, recipient, amount);
    }

    /**
     * @notice Repays debt for a borrower
     * @dev Accepts repayment for both base debt and penalty debt. Penalty debt is paid first.
     * Partial repayments of base debt will proportionally reduce the time until penalties start.
     * @param amount The amount of assets to repay
     * @param borrower The address whose debt is being repaid
     * @custom:revert ZeroRepayment If amount is 0
     * @custom:revert NoDebt If the borrower has no outstanding debt
     */
    function repay(uint amount, address borrower) public {
        _repay(amount, borrower, false);
    }

    /**
     * @notice Allows owner to forgive debt without requiring asset transfer
     * @dev Similar to repay() but doesn't require actual asset transfer
     * @param amount The amount of debt to forgive
     * @param borrower The address whose debt is being forgiven
     * @custom:revert ZeroRepayment If amount is 0
     * @custom:revert NoDebt If the borrower has no outstanding debt
     */
    function forgiveDebt(uint amount, address borrower) public onlyOwner() {
        _repay(amount, borrower, true);
    }

    /**
     * @notice Updates the InventoryPoolParams01 contract address
     * @dev Allows upgrading to a new parameters contract while maintaining the same pool
     * @param paramsContract The address of the new InventoryPoolParams01 contract
     */
    function upgrageParamsContract(address paramsContract) public onlyOwner() {
        params = IInventoryPoolParams01(paramsContract);
    }

    /**
     * @notice Returns the total assets managed by this pool
     * @dev Includes both the actual balance and all outstanding receivables
     * @return The total assets in the pool
     */
    function totalAssets() public view override(ERC4626, IInventoryPool01) returns (uint) {
        return totalReceivables() + IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @notice Returns the total amount of debt owed to the pool
     * @dev Includes both base debt and accrued interest for all borrowers. Does not include penalty debt
     * @return The total receivables amount
     */
    function totalReceivables() public view returns (uint) {
        return _totalReceivables(accumulatedInterestFactor());
    }

    /**
     * @notice Calculates the current utilization rate of the pool
     * @dev Utilization = Total Receivables / Total Assets
     * @return The utilization rate in 1e27 precision
     */
    function utilizationRate() public view returns (uint) {
        uint totalReceivables_ = totalReceivables();
        uint totalAssets_ = totalReceivables_ + IERC20(asset()).balanceOf(address(this));
        return totalReceivables_.mulDiv(1e27, totalAssets_);
    }

    /**
     * @notice Returns the current base debt for a borrower
     * @dev Base debt includes the original borrowed amount plus accrued interest,
     * but excludes any penalty interest
     * @param borrower The borrower's address
     * @return The current base debt amount for the borrower
     */
    function baseDebt(address borrower) public view returns (uint) {
        return _baseDebt(borrower, accumulatedInterestFactor());
    }

    /**
     * @notice Returns the current penalty debt for a borrower
     * @dev Penalty debt only exists after the penalty period has passed
     * and is calculated based on the penalty rate
     * @param borrower The borrower's address
     * @return The current penalty debt amount for the borrower
     */
    function penaltyDebt(address borrower) public view returns (uint) {
        return _penaltyDebt(borrower, accumulatedInterestFactor());
    }

    /**
     * @notice Returns how long a borrower has been in the penalty period
     * @dev Returns 0 if not in penalty period, otherwise returns seconds since penalty started
     * @param borrower The borrower's address
     * @return The number of seconds in penalty period, or 0 if not in penalty period
     */
    function penaltyTime(address borrower) public view returns (uint) {
        uint penaltyCounterStart = borrowers[borrower].penaltyCounterStart;
        if (penaltyCounterStart > 0) {
            uint penaltyCounterEnd = penaltyCounterStart + params.penaltyPeriod();
            if (penaltyCounterEnd < block.timestamp) {
                return block.timestamp - penaltyCounterEnd;
            }
        }
        return 0;
    }

    /**
     * @notice Returns the accumulated interest factor for the pool
     * @dev Used to calculate the base debt for borrowers
     * @return The accumulated interest factor in 1e27 precision
     */
    function accumulatedInterestFactor() public view returns (uint) {
        if (storedAccInterestFactor == 0) {
            return 1e27;
        } else {
            // newFactor = oldFactor * (1 + ratePerSecond * secondsSinceLastUpdate)
            return storedAccInterestFactor.mulDiv(
                1e27 + params.interestRate(_utilizationRate(storedAccInterestFactor)) * (block.timestamp - lastAccumulatedInterestUpdate),
                1e27,
                Math.Rounding.Ceil
            );
        }
    }

    /**
     * @notice Internal function to handle debt repayment
     * @dev Handles both base debt and penalty debt repayment
     * @param amount The amount of assets to repay
     * @param borrower The borrower's address
     * @param forgive If true, debt is forgiven without requiring asset transfer
     * @custom:revert ZeroRepayment If amount is 0
     * @custom:revert NoDebt If the borrower has no outstanding debt
     */
    function _repay(uint amount, address borrower, bool forgive) internal nonReentrant() {
        if (amount == 0) {
          revert ZeroRepayment();
        }

        _updateAccumulatedInterestFactor();

        uint baseDebt_ = _baseDebt(borrower, storedAccInterestFactor);
        if (baseDebt_ == 0) {
            revert NoDebt();
        }

        uint baseDebtPayment_;

        uint penaltyDebt_ = _penaltyDebt(borrower, storedAccInterestFactor);
        uint penaltyPayment_ = 0;
        if (penaltyDebt_ > 0) {
            if (amount > penaltyDebt_) {
                // payment amount is greater than penalty debt.
                // after penalty debt is paid, the remaining amount goes to base debt payment
                baseDebtPayment_ = amount - penaltyDebt_;
                // set penalty payment to full penalty debt amount
                penaltyPayment_ = penaltyDebt_;
                // reset partial penalty payment
                borrowers[borrower].partialPenaltyPayment = 0;
            } else {
                // payment amount is less than penalty debt.
                // store partial payment amount.
                // this will be used to calculate the remaining penalty debt.
                borrowers[borrower].partialPenaltyPayment += amount;
                penaltyPayment_ = amount;
            }
            emit PenaltyRepayment(borrower, penaltyDebt_, penaltyPayment_);
        } else {
            // no penalty debt, full payment amount is used to pay base debt
            baseDebtPayment_ = amount;
        }
        
        if (baseDebtPayment_ > 0) {
            if (baseDebtPayment_ >= baseDebt_) {
                // full repayment of base debt.
                // reset penalty counter start time.
                borrowers[borrower].penaltyCounterStart = 0;
                // set base debt payment to base debt amount, in case of overpayment
                baseDebtPayment_ = baseDebt_;
            } else {
                // partial repayment of base debt.
                // increase the penalty counter start time based on the amount of base debt repaid.
                uint timeElapsed_ = block.timestamp - borrowers[borrower].penaltyCounterStart;
                uint paymentRatio_ = baseDebtPayment_.mulDiv(1e27, baseDebt_);
                borrowers[borrower].penaltyCounterStart = block.timestamp - timeElapsed_ + paymentRatio_.mulDiv(timeElapsed_, 1e27);
            }

            uint scaledDebt_ = baseDebtPayment_.mulDiv(1e27, storedAccInterestFactor, Math.Rounding.Ceil);
            borrowers[borrower].scaledDebt -= scaledDebt_;
            scaledReceivables -= scaledDebt_;

            emit BaseDebtRepayment(borrower, baseDebt_, baseDebtPayment_);
        }

        if (!forgive) {
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), baseDebtPayment_ + penaltyPayment_);
        }
    }

    /**
     * @notice ERC4626 override to handle deposit
     * @dev Updates the accumulated interest factor after deposit, because deposit will decrease
     * the utlization rate which will decrease the pool's interest rate
     * @param caller The caller's address
     * @param receiver The receiver's address
     * @param assets The amount of assets to deposit
     * @param shares The amount of shares to mint
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant() {
        ERC4626._deposit(caller, receiver, assets, shares);

        _updateAccumulatedInterestFactor();
    }

    /**
     * @notice ERC4626 override to handle withdraw
     * @dev Updates the accumulated interest factor after withdraw, because withdraw will increase
     * the utlization rate which will increase the pool's interest rate. If a shareholder owns more
     * shares than the amount of unborrowed assets, the shareholder can only withdraw up to the amount
     * of unborrowed assets, otherwise an InsufficientLiquidity error will be thrown.
     * @param caller The caller's address
     * @param receiver The receiver's address
     * @param owner The owner's address
     * @param assets The amount of assets to withdraw
     * @param shares The amount of shares to burn
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant() {
        if (assets > IERC20(asset()).balanceOf(address(this))) {
            revert InsufficientLiquidity();
        }
        ERC4626._withdraw(caller, receiver, owner, assets, shares);

        _updateAccumulatedInterestFactor();
    }

    /**
     * @notice Internal function to update the accumulated interest factor
     * @dev Updates the stored accumulated interest factor and the last update timestamp
     */
    function _updateAccumulatedInterestFactor () internal {
        storedAccInterestFactor = accumulatedInterestFactor();
        lastAccumulatedInterestUpdate = block.timestamp;
    }

    /**
     * @notice Internal function to calculate the utilization rate
     * @dev Utilization rate = Total Receivables / Total Assets
     * @param accInterestFactor The accumulated interest factor
     * @return The utilization rate in 1e27 precision
     */
    function _utilizationRate(uint accInterestFactor) internal view returns (uint) {
        uint totalReceivables_ = _totalReceivables(accInterestFactor);
        uint totalAssets_ = totalReceivables_ + IERC20(asset()).balanceOf(address(this));
        return totalReceivables_.mulDiv(1e27, totalAssets_);
    }

    /**
     * @notice Internal function to calculate the total receivables
     * @dev Total receivables = scaled receivables * accumulated interest factor
     * @param accInterestFactor The accumulated interest factor
     * @return The total receivables amount
     */
    function _totalReceivables(uint accInterestFactor) internal view returns (uint) {
        return scaledReceivables.mulDiv(accInterestFactor, 1e27);
    }

    /**
     * @notice Internal function to calculate the base debt for a borrower
     * @dev Base debt = scaled debt * accumulated interest factor
     * @param borrower The borrower's address
     * @param accInterestFactor The accumulated interest factor
     * @return The base debt amount for the borrower
     */
    function _baseDebt(address borrower, uint accInterestFactor) internal view returns (uint) {
        return borrowers[borrower].scaledDebt.mulDiv(accInterestFactor, 1e27);
    }

    /**
     * @notice Internal function to calculate the penalty debt for a borrower
     * @dev Penalty debt = (base debt * penalty time * penalty rate) - penalty debt paid
     * @param borrower The borrower's address
     * @param accInterestFactor The accumulated interest factor
     * @return The penalty debt amount for the borrower
     */
    function _penaltyDebt(address borrower, uint accInterestFactor) internal view returns (uint) {
        uint penaltyTime_ = penaltyTime(borrower);
        if (penaltyTime_ == 0) return 0;

        return (_baseDebt(borrower, accInterestFactor) * penaltyTime_).mulDiv(params.penaltyRate(), 1e27) - borrowers[borrower].partialPenaltyPayment;
    }

    /**
     * @notice Fallback function to prevent accidental ETH deposits
     * @dev Reverts if ETH is transferred to the pool
     */
    receive() external payable {
        revert NotSupported();
    }
}
