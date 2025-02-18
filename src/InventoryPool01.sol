// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

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
    uint penaltyDebtPaid;
}

/**
 * @title InventoryPool01
 * @dev An ERC4626-compliant lending pool that allows borrowing against deposited assets.
 * Features include:
 * - Variable interest rates based on pool utilization
 * - Penalty interest for overdue loans
 * - Owner-controlled borrowing permissions
 * - Protection against inflation attacks
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
        address params_
    ) ERC4626(IERC20(asset_)) ERC20(name, symbol) Ownable(owner) {
        /**
         * deployer is responsible for burning a small deposit to mitigate inflation attack.
         * this ERC4626 implementation uses offset to make inflation attack un-profitable
         * but burning a small initial deposit eliminates the possibility of a griefing attack
         */
        deposit(initAmount, 0x000000000000000000000000000000000000dEaD);

        params = IInventoryPoolParams01(params_);
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

        uint scaledDebt_ = amount.mulDiv(1e27, storedAccInterestFactor) + amount.mulDiv(params.baseFee(), 1e27);
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
     * @dev Similar to repay() but doesn't require actual asset transfer.
     * Useful for handling bad debt or special arrangements.
     * @param amount The amount of debt to forgive
     * @param borrower The address whose debt is being forgiven
     */
    function repayOwnerOverride(uint amount, address borrower) public onlyOwner() {
        _repay(amount, borrower, true);
    }

    /**
     * @notice Updates the parameters contract address
     * @dev Allows upgrading to a new parameters contract while maintaining the same pool logic
     * @param params_ The address of the new parameters contract
     */
    function upgrageParamsContract(address params_) public onlyOwner() {
        params = IInventoryPoolParams01(params_);
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
     * @dev Includes both base debt and accrued interest for all borrowers
     * @return The total receivables amount
     */
    function totalReceivables() public view returns (uint) {
        return _totalReceivables(accumulatedInterestFactor());
    }

    /**
     * @notice Calculates the current utilization rate of the pool
     * @dev Utilization = Total Receivables / Total Assets
     * Used to determine the current interest rate
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
     * @param borrower The address to check
     * @return The current base debt amount
     */
    function baseDebt(address borrower) public view returns (uint) {
        return _baseDebt(borrower, accumulatedInterestFactor());
    }

    /**
     * @notice Returns the current penalty debt for a borrower
     * @dev Penalty debt only exists after the penalty period has passed
     * and is calculated based on the penalty rate
     * @param borrower The address to check
     * @return The current penalty debt amount
     */
    function penaltyDebt(address borrower) public view returns (uint) {
        return _penaltyDebt(borrower, accumulatedInterestFactor());
    }

    /**
     * @notice Returns how long a borrower has been in the penalty period
     * @dev Returns 0 if not in penalty period, otherwise returns seconds since penalty started
     * @param borrower The address to check
     * @return The number of seconds in penalty period, or 0 if not in penalty
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

    function accumulatedInterestFactor() public view returns (uint) {
        if (storedAccInterestFactor == 0) {
            return 1e27;
        } else {
            // newFactor = oldFactor * (1 + ratePerSecond * secondsSinceLastUpdate)
            return storedAccInterestFactor.mulDiv(
                1e27 + params.interestRate(_utilizationRate(storedAccInterestFactor)) * (block.timestamp - lastAccumulatedInterestUpdate),
                1e27
            );
        }
    }

    function _repay(uint amount, address borrower, bool ownerOverride) internal nonReentrant() {
        if (amount == 0) {
          revert ZeroRepayment();
        }

        _updateAccumulatedInterestFactor();

        uint baseDebt_ = _baseDebt(borrower, storedAccInterestFactor);
        if (baseDebt_ == 0) {
            revert NoDebt();
        }

        uint baseDebtPayment_ = amount;

        uint penaltyDebt_ = _penaltyDebt(borrower, storedAccInterestFactor);
        uint penaltyPayment_ = 0;
        if (penaltyDebt_ > 0) {
            if (baseDebtPayment_ > penaltyDebt_) {
                baseDebtPayment_ -= penaltyDebt_;
                penaltyPayment_ = penaltyDebt_;
                borrowers[borrower].penaltyDebtPaid = 0;
            } else {
                borrowers[borrower].penaltyDebtPaid += amount;
                penaltyPayment_ = amount;
                baseDebtPayment_ = 0;
            }
            emit PenaltyRepayment(borrower, penaltyDebt_, penaltyPayment_);
        }
        
        if (baseDebtPayment_ > 0) {
            if (baseDebtPayment_ >= baseDebt_) {
                borrowers[borrower].penaltyCounterStart = 0;
                baseDebtPayment_ = baseDebt_;
            } else {
                uint period_ = params.penaltyPeriod();
                uint paymentRatio_ = baseDebtPayment_.mulDiv(1e27, baseDebt_);
                borrowers[borrower].penaltyCounterStart = block.timestamp - period_ + paymentRatio_.mulDiv(period_, 1e27);
            }

            uint scaledDebt_ = baseDebtPayment_.mulDiv(1e27, storedAccInterestFactor, Math.Rounding.Ceil);
            borrowers[borrower].scaledDebt -= scaledDebt_;
            scaledReceivables -= scaledDebt_;

            emit BaseDebtRepayment(borrower, baseDebt_, baseDebtPayment_);
        }

        if (!ownerOverride) {
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), baseDebtPayment_ + penaltyPayment_);
        }
    }
    
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant() {
        ERC4626._deposit(caller, receiver, assets, shares);

        _updateAccumulatedInterestFactor();
    }

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

    function _updateAccumulatedInterestFactor () internal {
        storedAccInterestFactor = accumulatedInterestFactor();
        lastAccumulatedInterestUpdate = block.timestamp;
    }

    function _utilizationRate(uint accInterestFactor) internal view returns (uint) {
        uint totalReceivables_ = _totalReceivables(accInterestFactor);
        uint totalAssets_ = totalReceivables_ + IERC20(asset()).balanceOf(address(this));
        return totalReceivables_.mulDiv(1e27, totalAssets_);
    }

    function _totalReceivables(uint accInterestFactor) internal view returns (uint) {
        return scaledReceivables.mulDiv(accInterestFactor, 1e27);
    }

    function _baseDebt(address borrower, uint accInterestFactor) internal view returns (uint) {
        return borrowers[borrower].scaledDebt.mulDiv(accInterestFactor, 1e27);
    }

    function _penaltyDebt(address borrower, uint accInterestFactor) internal view returns (uint) {
        uint penaltyTime_ = penaltyTime(borrower);
        if (penaltyTime_ == 0) return 0;

        return (_baseDebt(borrower, accInterestFactor) * penaltyTime_).mulDiv(params.penaltyRate(), 1e27) - borrowers[borrower].penaltyDebtPaid;
    }

    receive() external payable {
        revert NotSupported();
    }

}
