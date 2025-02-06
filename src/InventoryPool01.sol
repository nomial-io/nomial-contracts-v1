// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {ERC4626, IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInventoryPool01} from "./interfaces/IInventoryPool01.sol";
import {IInventoryPoolParams01} from "./interfaces/IInventoryPoolParams01.sol";

error NotSupported();
error Expired();
error NoDebt();
error ZeroRepayment();
error InsufficientLiquidity();

struct BorrowerData {
    uint scaledDebt;
    uint penaltyCounterStart;
    uint penaltyDebtPaid;
}

/**
 * @dev ...
 * ...
 */
contract InventoryPool01 is ERC4626, Ownable, IInventoryPool01 {
    using Math for uint256;

    IInventoryPoolParams01 public params;
    uint public storedAccInterestFactor;
    uint public lastAccumulatedInterestUpdate;
    uint public scaledReceivables;

    mapping(address => BorrowerData) public borrowers;

    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint initAmount,
        address owner,
        IInventoryPoolParams01 _params
    ) ERC4626(IERC20(asset)) ERC20(name, symbol) Ownable(owner) {
        /**
         * deployer is responsible for burning a small deposit to mitigate inflation attack.
         * this ERC4626 implementation uses offset to make inflation attack un-profitable
         * but burning a small initial deposit eliminates the possibility of a griefing attack
         */
        deposit(initAmount, 0x000000000000000000000000000000000000dEaD);

        params = _params;
    }

    function borrow(uint amount, address borrower, address recipient, uint expiryTime) public onlyOwner() {
        if (expiryTime <= block.timestamp) {
            revert Expired();
        }

        _updateAccumulatedInterestFactor();

        uint scaledDebt_ = amount.mulDiv(1e27, storedAccInterestFactor) + amount.mulDiv(params.baseFee(), 1e27);
        borrowers[borrower].scaledDebt += scaledDebt_;
        scaledReceivables += scaledDebt_;
        if (borrowers[borrower].penaltyCounterStart == 0) {
            borrowers[borrower].penaltyCounterStart = block.timestamp;
        }

        IERC20(asset()).transfer(recipient, amount);
    }

    function repay(uint amount, address borrower) public {
        if (amount == 0) {
          revert ZeroRepayment();
        }

        _updateAccumulatedInterestFactor();

        uint baseDebt_ = _baseDebt(borrower, storedAccInterestFactor);
        if (baseDebt_ == 0) {
            revert NoDebt();
        }

        uint baseDebtPayment_ = amount;

        uint penaltyDebt_ = penaltyDebt(borrower);
        if (penaltyDebt_ > 0) {
            if (baseDebtPayment_ > penaltyDebt_) {
                baseDebtPayment_ -= penaltyDebt_;
                borrowers[borrower].penaltyDebtPaid = 0;
            } else {
                borrowers[borrower].penaltyDebtPaid += amount;
                return;
            }
        }
        
        if (baseDebtPayment_ >= baseDebt_) {
            borrowers[borrower].penaltyCounterStart = 0;
            baseDebtPayment_ = baseDebt_;
        } else {
            uint period_ = params.penaltyPeriod();
            uint paymentRatio_ = baseDebtPayment_.mulDiv(1e27, baseDebt_);
            borrowers[borrower].penaltyCounterStart = block.timestamp - period_ + paymentRatio_.mulDiv(period_, 1e27);
        }

        uint scaledDebt_ = baseDebtPayment_.mulDiv(1e27, storedAccInterestFactor);
        borrowers[borrower].scaledDebt -= scaledDebt_;
        scaledReceivables -= scaledDebt_;

        IERC20(asset()).transferFrom(msg.sender, address(this), baseDebtPayment_);
    }

    function absolvePenalty (address borrower) public onlyOwner() {
        BorrowerData storage b = borrowers[borrower];
        b.penaltyCounterStart = 0;
        b.penaltyDebtPaid = 0;
    }

    function setParamsContract (address params_) public onlyOwner() {
        params = IInventoryPoolParams01(params_);
    }

    function totalAssets() public view override(ERC4626, IInventoryPool01) returns (uint) {
        return receivables() + IERC20(asset()).balanceOf(address(this));
    }

    function receivables() public view returns (uint) {
        return scaledReceivables.mulDiv(accumulatedInterestFactor(), 1e27);
    }

    function baseDebt(address borrower) public view returns (uint) {
        return _baseDebt(borrower, accumulatedInterestFactor());
    }

    function penaltyDebt(address borrower) public view returns (uint) {
        uint penaltyTime_ = penaltyTime(borrower);
        if (penaltyTime_ == 0) return 0;

        return penaltyTime_.mulDiv(params.penaltyRate(), 1e27) - borrowers[borrower].penaltyDebtPaid;
    }

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
            return storedAccInterestFactor.mulDiv(1e27 + params.interestRate() * (block.timestamp - lastAccumulatedInterestUpdate), 1e27);
        }
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (assets > IERC20(asset()).balanceOf(address(this))) {
            revert InsufficientLiquidity();
        }
        ERC4626._withdraw(caller, receiver, owner, assets, shares);
    }

    function _updateAccumulatedInterestFactor () internal {
        storedAccInterestFactor = accumulatedInterestFactor();
        lastAccumulatedInterestUpdate = block.timestamp;
    }

    function _baseDebt(address borrower, uint accInterestFactor) internal view returns (uint) {
        return borrowers[borrower].scaledDebt.mulDiv(accInterestFactor, 1e27);
    }

    receive() external payable {
        revert NotSupported();
    }

}
