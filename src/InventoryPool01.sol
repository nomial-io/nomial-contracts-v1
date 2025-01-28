// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {ERC4626, IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

    uint private globalScaledDebt;
    uint private accumulatedInterestFactor_;
    uint private lastAccumulatedInterestUpdate;

    struct BorrowerData {
      uint scaledDebt;
    }

    mapping(address => BorrowerData) public borrowers;
    /**
     * @dev Alias for onlyOwner()
     */
    modifier onlyBorrowController() {
        _checkOwner();
        _;
    }

    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint initAmount,
        address borrowController
    ) ERC4626(IERC20(asset)) ERC20(name, symbol) Ownable(borrowController) {
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
    }

    function borrow(uint amount, address borrower, address recipient) public onlyBorrowController() {
      _updateAccumulatedInterestFactor();
      uint scaledDebt = amount.mulDiv(1e27, accumulatedInterestFactor_, Math.Rounding.Floor) + amount.mulDiv(baseFee(), 1e27, Math.Rounding.Floor);
      borrowers[borrower].scaledDebt += scaledDebt;
      globalScaledDebt += scaledDebt;
    }

    function repay(uint amount, address borrower) public {
      _updateAccumulatedInterestFactor();

    }

    /**
     * @dev Alias for owner()
     */
    function borrowController() public view returns (address) {
      return owner();
    }

    function baseFee() public view returns (uint) {
      return baseFee_;
    }

    function interestRate() public view returns (uint) {
      return interestRate_;
    }

    function accumulatedInterestFactor () public view returns (uint) {
      if (accumulatedInterestFactor_ == 0) {
        return 1e27;
      } else {
        // newFactor = oldFactor * (1 + ratePerSecond * secondsSinceLastUpdate)
        return accumulatedInterestFactor_ * (1e27 + interestRate() * (block.timestamp - lastAccumulatedInterestUpdate));
      }
    }

    function _updateAccumulatedInterestFactor () private {
      accumulatedInterestFactor_ = accumulatedInterestFactor();
      lastAccumulatedInterestUpdate = block.timestamp;
    }

}
