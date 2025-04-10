// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IInventoryPoolParams01} from "../interfaces/IInventoryPoolParams01.sol";
import {OwnableParams01} from "../OwnableParams01.sol";
import {InventoryPool01} from "../InventoryPool01.sol";

/**
 * @title InventoryPoolDefaultAccessManager01
 * @notice Access control contract for management of InventoryPool01 contracts
 * @dev Defines VALIDATOR_ROLE and BORROWER_ROLE, and exposes functions for these roles to interact with pools
 */
contract InventoryPoolDefaultAccessManager01 is AccessControlEnumerable, EIP712 {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

    bytes32 private constant BORROW_TYPEHASH = keccak256(
        "Borrow(address pool,address borrower,uint256 amount,address recipient,uint256 expiry,uint256 chainId,bytes32 salt)"
    );

    error SignatureUsed(bytes32 sigHash);
    error BorrowerLoanDefault(InventoryPool01 pool, address borrower);
    error BorrowerDebtLimitExceeded(
        InventoryPool01 pool, address borrower, uint currentDebt, uint debtLimit, uint borrowAmount
    );

    // Maximum debt a borrower is allowed for a pool. 0 means no limit.
    mapping(InventoryPool01 pool => mapping(address borrower => uint debtLimit)) public borrowerDebtLimit;

    // Track used signatures to prevent replay
    mapping(bytes32 => bool) public usedSigHashes;

    constructor(address admin) EIP712("InventoryPoolDefaultAccessManager01", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(BORROWER_ROLE, VALIDATOR_ROLE);
    }

    /**
     * @notice Execute borrow on an inventory pool
     * @dev Can only be called by a borrower with a signature from a validator
     * @param pool Address of the inventory pool contract, which should have this contract set as owner
     * @param amount Amount to borrow from pool
     * @param recipient Address to receive the borrowed assets
     * @param expiry Timestamp after which the borrow is no longer valid
     * @param salt Value for uniqueness of signature hash
     * @param signature EIP-712 signature from a validator
     */
    function borrow(
        InventoryPool01 pool,
        uint amount,
        address recipient,
        uint expiry,
        bytes32 salt,
        bytes calldata signature
    ) external onlyRole(BORROWER_ROLE) {
        address borrower = _msgSender();

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    BORROW_TYPEHASH, pool, borrower, amount, recipient, expiry, block.chainid, salt
                )
            )
        );

        if (usedSigHashes[digest]) {
            revert SignatureUsed(digest);
        }

        _checkRole(VALIDATOR_ROLE, ECDSA.recover(digest, signature));

        uint penaltyDebt = pool.penaltyDebt(borrower);
        if (penaltyDebt > 0) {
            revert BorrowerLoanDefault(pool, borrower);
        }

        uint baseDebt = pool.baseDebt(borrower);
        uint debtLimit = borrowerDebtLimit[pool][borrower];
        if (debtLimit > 0 && baseDebt + amount > debtLimit) {
            revert BorrowerDebtLimitExceeded(pool, borrower, baseDebt, debtLimit, amount);
        }

        usedSigHashes[digest] = true;

        pool.borrow(amount, borrower, recipient, expiry, block.chainid);
    }

    function setBorrowerDebtLimit(
        InventoryPool01 pool,
        address borrower,
        uint debtLimit
    ) external onlyRole(VALIDATOR_ROLE) {
        borrowerDebtLimit[pool][borrower] = debtLimit;
    }

    function forgiveDebt(
        InventoryPool01 pool,
        uint amount,
        address borrower
    ) external onlyRole(VALIDATOR_ROLE) {
        pool.forgiveDebt(amount, borrower);
    }

    function updateBaseFee(OwnableParams01 paramsContract, uint newBaseFee) external onlyRole(VALIDATOR_ROLE) {
        paramsContract.updateBaseFee(newBaseFee);
    }

    function updateInterestRate(OwnableParams01 paramsContract, uint newInterestRate) external onlyRole(VALIDATOR_ROLE) {
        paramsContract.updateInterestRate(newInterestRate);
    }

    function updatePenaltyRate(OwnableParams01 paramsContract, uint newPenaltyRate) external onlyRole(VALIDATOR_ROLE) {
        paramsContract.updatePenaltyRate(newPenaltyRate);
    }

    function updatePenaltyPeriod(OwnableParams01 paramsContract, uint newPenaltyPeriod) external onlyRole(VALIDATOR_ROLE) {
        paramsContract.updatePenaltyPeriod(newPenaltyPeriod);
    }

    function upgradeParamsContract(InventoryPool01 pool, IInventoryPoolParams01 paramsContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pool.upgradeParamsContract(paramsContract);
    }

    function overwriteCoreState(
        InventoryPool01 pool,
        uint newStoredAccInterestFactor,
        uint newLastAccumulatedInterestUpdate,
        uint newScaledReceivables
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pool.overwriteCoreState(newStoredAccInterestFactor, newLastAccumulatedInterestUpdate, newScaledReceivables);
    }

    function transferOwnership(Ownable ownedContract, address newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ownedContract.transferOwnership(newOwner);
    }
}
