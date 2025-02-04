// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {ERC4626, IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
contract InventoryPool01 is ERC4626, Ownable {
    using Math for uint256;

    /* The initial fee for borrows. A fixed percentage expressed in 1e27 */
    uint public baseFee_;

    /* Time-based rate for interest on borrows. Rate is per-second expressed in 1e27 */
    uint private interestRate_;

    uint private penaltyRate_;
    uint private penaltyPeriod_;

    uint private accumulatedInterestFactor_;

    uint private globalScaledDebt;
    uint private lastAccumulatedInterestUpdate;

    mapping(address => BorrowerData) public borrowers;

    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint initAmount,
        address owner
    ) ERC4626(IERC20(asset)) ERC20(name, symbol) Ownable(owner) {
        /**
         * deployer is responsible for burning a small deposit to mitigate inflation attack.
         * this ERC4626 implementation uses offset to make inflation attack un-profitable
         * but burning a small initial deposit eliminates the possibility of a griefing attack
         */
        deposit(initAmount, 0x000000000000000000000000000000000000dEaD);

        // 1 bps (0.01 %)
        baseFee_ = 1 * 1e23;

        // 5% annual rate, per second
        // 5 * 1e25 / (60 * 60 * 24 * 365)
        interestRate_ = 1585489599188229400;

        // 500% annual penalty rate, per second
        // 500 * 1e25 / (60 * 60 * 24 * 365)
        penaltyRate_ = 158548959918822932521;

        // 24 hour penalty period, in seconds
        penaltyPeriod_ = 86400;
    }

    function borrow(uint amount, address borrower, address recipient, uint expiryTime) public onlyOwner() {
      if (expiryTime <= block.timestamp) {
        revert Expired();
      }

      _updateAccumulatedInterestFactor();

      uint scaledDebt = amount.mulDiv(1e27, accumulatedInterestFactor_) + amount.mulDiv(baseFee(), 1e27);
      borrowers[borrower].scaledDebt += scaledDebt;
      globalScaledDebt += scaledDebt;
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

        uint baseDebt_ = _baseDebt(borrower, accumulatedInterestFactor_);
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
            IERC20(asset()).transferFrom(msg.sender, address(this), baseDebt_);
        } else {
            uint period_ = penaltyPeriod();
            uint paymentRatio_ = baseDebtPayment_.mulDiv(1e27, baseDebt_);
            borrowers[borrower].penaltyCounterStart = block.timestamp - period_ + paymentRatio_.mulDiv(period_, 1e27);
            IERC20(asset()).transferFrom(msg.sender, address(this), baseDebtPayment_);
        }
    }

    function totalAssets() public view override returns (uint256) {
        return globalDebt() + IERC20(asset()).balanceOf(address(this));
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

    function baseFee() public view returns (uint) {
        return baseFee_;
    }

    function interestRate() public view returns (uint) {
        return interestRate_;
    }

    function penaltyRate() public view returns (uint) {
        return penaltyRate_;
    }

    function penaltyPeriod() public view returns (uint) {
        return penaltyPeriod_;
    }

    function globalDebt() public view returns (uint) {
        return globalScaledDebt.mulDiv(_accumulatedInterestFactor(), 1e27);
    }

    function baseDebt(address borrower) public view returns (uint) {
        return _baseDebt(borrower, _accumulatedInterestFactor());
    }

    function penaltyDebt(address borrower) public view returns (uint) {
        uint penaltyTime_ = penaltyTime(borrower);
        if (penaltyTime_ == 0) return 0;

        return penaltyTime_.mulDiv(penaltyRate(), 1e27) - borrowers[borrower].penaltyDebtPaid;
    }

    function penaltyTime(address borrower) public view returns (uint) {
        uint penaltyCounterStart = borrowers[borrower].penaltyCounterStart;
        if (penaltyCounterStart > 0) {
            uint penaltyCounterEnd = penaltyCounterStart + penaltyPeriod();
            if (penaltyCounterEnd < block.timestamp) {
                return block.timestamp - penaltyCounterEnd;
            }
        }
        return 0;
    }

    function _baseDebt(address borrower, uint accInterestFactor) internal view returns (uint) {
        return borrowers[borrower].scaledDebt.mulDiv(accInterestFactor, 1e27);
    }

    function _accumulatedInterestFactor() internal view returns (uint) {
        if (accumulatedInterestFactor_ == 0) {
            return 1e27;
        } else {
            // newFactor = oldFactor * (1 + ratePerSecond * secondsSinceLastUpdate)
            return accumulatedInterestFactor_.mulDiv(1e27 + interestRate() * (block.timestamp - lastAccumulatedInterestUpdate), 1e27);
        }
    }

    function _updateAccumulatedInterestFactor () internal {
        accumulatedInterestFactor_ = _accumulatedInterestFactor();
        lastAccumulatedInterestUpdate = block.timestamp;
    }

    receive() external payable {
        revert NotSupported();
    }

}
