// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {InventoryPoolDefaultAccessManager01} from "../src/owners/InventoryPoolDefaultAccessManager01.sol";
import {InventoryPool01} from "../src/InventoryPool01.sol";
import {IInventoryPool01} from "../src/interfaces/IInventoryPool01.sol";
import {InventoryPoolDefaultAccessManagerDeployer01} from "../src/deployment/InventoryPoolDefaultAccessManagerDeployer01.sol";
import {InventoryPoolDeployer01} from "../src/deployment/InventoryPoolDeployer01.sol";
import {OwnableParamsDeployer01} from "../src/deployment/OwnableParamsDeployer01.sol";
import {NomialDeployer01} from "../src/deployment/NomialDeployer01.sol";
import {OwnableParams01} from "../src/OwnableParams01.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./Helper.sol";
import {console} from "forge-std/console.sol";

contract InventoryPoolDefaultAccessManager01Test is Test, Helper {    
    address public constant admin = address(1);
    address public constant validator = address(2);
    address public constant borrower = address(3);
    address public constant recipient = address(4);
    bytes32 public constant salt1 = bytes32(uint256(1));
    bytes32 public constant salt2 = bytes32(uint256(2));

    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    uint256 public constant validator1_pk = 0x3;
    uint256 public constant validator2_pk = 0x4;
    uint256 public constant validator3_pk = 0x5;
    address public validator1 = vm.addr(validator1_pk);
    address public validator2 = vm.addr(validator2_pk);
    address public validator3 = vm.addr(validator3_pk);

    address[] public validators = [validator1, validator2, validator3];
    uint16 public signatureThreshold = 2;

    InventoryPoolDeployer01 public poolDeployer;
    OwnableParamsDeployer01 public ownableParamsDeployer;
    NomialDeployer01 public nomialDeployer;
    InventoryPoolDefaultAccessManagerDeployer01 public accessManagerDeployer;
    InventoryPool01 public wethInventoryPool;
    address public accessManagerAddr;
    InventoryPoolDefaultAccessManager01 public accessManager;
    OwnableParams01 public ownableParams;

    function setUp() public {
        setupAll();

        poolDeployer = new InventoryPoolDeployer01();
        ownableParamsDeployer = new OwnableParamsDeployer01();
        accessManagerDeployer = new InventoryPoolDefaultAccessManagerDeployer01();
        nomialDeployer = new NomialDeployer01(
            address(poolDeployer),
            address(ownableParamsDeployer),
            address(accessManagerDeployer)
        );

        // Deploy WETH pool
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable wethPoolAddress,,address payable wethPoolAccessManager_) = nomialDeployer.deploy(
            salt2,
            abi.encode(admin, validators, signatureThreshold),
            abi.encode(defaultBaseFee, defaultRate1, defaultPenaltyRate, defaultPenaltyPeriod),
            abi.encode(IERC20(WETH), "nomialWETH", "nmlWETH", 1 * 10**14),
            WETH_WHALE
        );
        wethInventoryPool = InventoryPool01(wethPoolAddress);
        accessManagerAddr = wethPoolAccessManager_;
        accessManager = InventoryPoolDefaultAccessManager01(accessManagerAddr);
        IERC20(WETH).approve(address(wethInventoryPool), MAX_UINT);
        wethInventoryPool.deposit(1_000 * 10**18, WETH_WHALE);
        vm.stopPrank();

        ownableParams = OwnableParams01(address(wethInventoryPool.params()));
    }

    function testInventoryPoolDefaultAccessManager01_constructor() public {
        assertTrue(accessManagerAddr.code.length > 0, "Access manager should be deployed");

        assertTrue(accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), admin), "Admin should have default role");

        for (uint i = 0; i < validators.length; i++) {
            assertTrue(accessManager.hasRole(accessManager.VALIDATOR_ROLE(), validators[i]), "Validator should have validator role");
        }

        assertTrue(accessManager.signatureThreshold() == signatureThreshold, "Signature threshold should be set");
    }

    function testInventoryPoolDefaultAccessManager01_constructor_duplicateValidatorReverts() public {
        address[] memory duplicateValidators = new address[](3);
        duplicateValidators[0] = validator1;
        duplicateValidators[1] = validator2;
        duplicateValidators[2] = validator1; // Duplicate validator1

        vm.expectRevert(abi.encodeWithSelector(InventoryPoolDefaultAccessManager01.ValidatorExists.selector, validator1));
        new InventoryPoolDefaultAccessManager01(
            admin,
            duplicateValidators,
            signatureThreshold
        );
    }

    function testInventoryPoolDefaultAccessManager01_constructor_zeroValidatorsReverts() public {
        address[] memory emptyValidators = new address[](0);
        
        vm.expectRevert(InventoryPoolDefaultAccessManager01.ZeroValidatorsNotAllowed.selector);
        new InventoryPoolDefaultAccessManager01(
            admin,
            emptyValidators,
            1
        );
    }

    function testInventoryPoolDefaultAccessManager01_borrow_success() public {
        InventoryPool01 pool = wethInventoryPool;
        uint amount = 1 * 10**18;
        uint expiry = block.timestamp + 100;
        bytes32 salt = bytes32(block.timestamp);
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.BORROW_TYPEHASH(),
            pool,
            borrower,
            amount,
            recipient,
            expiry,
            block.chainid,
            salt
        )));

        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.prank(borrower);
        vm.expectEmit(true, true, true, true);
        emit IInventoryPool01.Borrowed(borrower, recipient, amount);
        accessManager.borrow(pool, amount, recipient, expiry, salt, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_borrow_nonValidatorSignatureReverts() public {
        InventoryPool01 pool = wethInventoryPool;
        uint amount = 1 * 10**18;
        uint expiry = block.timestamp + 100;
        bytes32 salt = bytes32(block.timestamp);
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.BORROW_TYPEHASH(),
            pool,
            borrower,
            amount,
            recipient,
            expiry,
            block.chainid,
            salt
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(borrower);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.borrow(pool, amount, recipient, expiry, salt, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_forgiveDebt_success() public {
        // First create a borrow position
        InventoryPool01 pool = wethInventoryPool;
        uint borrowAmount = 1 * 10**18;
        uint expiry = block.timestamp + 100;
        bytes32 borrowSalt = bytes32(block.timestamp);
        
        // Create and sign borrow digest
        bytes32 borrowDigest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.BORROW_TYPEHASH(),
            pool,
            borrower,
            borrowAmount,
            recipient,
            expiry,
            block.chainid,
            borrowSalt
        )));

        bytes[] memory borrowSignatures = getValidatorSignatures(borrowDigest);

        // Execute borrow
        vm.prank(borrower);
        accessManager.borrow(pool, borrowAmount, recipient, expiry, borrowSalt, borrowSignatures);

        uint debtAmount = pool.baseDebt(borrower);

        // get signatures for forgive debt
        bytes32 forgiveDigest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.FORGIVE_DEBT_TYPEHASH(),
            pool,
            debtAmount,
            borrower
        )));
        bytes[] memory forgiveSignatures = getValidatorSignatures(forgiveDigest);

        // Execute forgive debt
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit IInventoryPool01.BaseDebtRepayment(borrower, debtAmount, debtAmount);
        accessManager.forgiveDebt(pool, debtAmount, borrower, forgiveSignatures);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_forgiveDebt_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.forgiveDebt(wethInventoryPool, 1 * 10**18, borrower, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_forgiveDebt_nonValidatorSignatureReverts() public {
        InventoryPool01 pool = wethInventoryPool;
        uint amount = 1 * 10**18;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.FORGIVE_DEBT_TYPEHASH(),
            pool,
            amount,
            borrower
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.forgiveDebt(pool, amount, borrower, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_updateBaseFee_success() public {
        uint newBaseFee = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_BASE_FEE_TYPEHASH(),
            ownableParams,
            newBaseFee
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit OwnableParams01.BaseFeeUpdated(defaultBaseFee, newBaseFee);
        accessManager.updateBaseFee(ownableParams, newBaseFee, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_updateBaseFee_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updateBaseFee(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updateBaseFee_nonValidatorSignatureReverts() public {
        uint newBaseFee = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_BASE_FEE_TYPEHASH(),
            ownableParams,
            newBaseFee
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.updateBaseFee(ownableParams, newBaseFee, signatures);
    }

    // Update interest rate tests
    function testInventoryPoolDefaultAccessManager01_updateInterestRate_success() public {
        uint newInterestRate = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_INTEREST_RATE_TYPEHASH(),
            ownableParams,
            newInterestRate
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit OwnableParams01.InterestRateUpdated(defaultRate1, newInterestRate);
        accessManager.updateInterestRate(ownableParams, newInterestRate, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_updateInterestRate_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updateInterestRate(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updateInterestRate_nonValidatorSignatureReverts() public {
        uint newInterestRate = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_INTEREST_RATE_TYPEHASH(),
            ownableParams,
            newInterestRate
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.updateInterestRate(ownableParams, newInterestRate, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyRate_success() public {
        uint newPenaltyRate = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_PENALTY_RATE_TYPEHASH(),
            ownableParams,
            newPenaltyRate
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit OwnableParams01.PenaltyRateUpdated(defaultPenaltyRate, newPenaltyRate);
        accessManager.updatePenaltyRate(ownableParams, newPenaltyRate, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyRate_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updatePenaltyRate(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyRate_nonValidatorSignatureReverts() public {
        uint newPenaltyRate = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_PENALTY_RATE_TYPEHASH(),
            ownableParams,
            newPenaltyRate
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.updatePenaltyRate(ownableParams, newPenaltyRate, signatures);
    }

    // Update penalty period tests
    function testInventoryPoolDefaultAccessManager01_updatePenaltyPeriod_success() public {
        uint newPenaltyPeriod = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_PENALTY_PERIOD_TYPEHASH(),
            ownableParams,
            newPenaltyPeriod
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit OwnableParams01.PenaltyPeriodUpdated(defaultPenaltyPeriod, newPenaltyPeriod);
        accessManager.updatePenaltyPeriod(ownableParams, newPenaltyPeriod, signatures);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyPeriod_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updatePenaltyPeriod(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyPeriod_nonValidatorSignatureReverts() public {
        uint newPenaltyPeriod = 100;
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPDATE_PENALTY_PERIOD_TYPEHASH(),
            ownableParams,
            newPenaltyPeriod
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.updatePenaltyPeriod(ownableParams, newPenaltyPeriod, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_upgradeParamsContract_success() public {
        OwnableParams01 newParams = new OwnableParams01(
            defaultBaseFee,
            defaultRate1,
            defaultPenaltyRate,
            defaultPenaltyPeriod,
            address(accessManager)
        );

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPGRADE_PARAMS_CONTRACT_TYPEHASH(),
            wethInventoryPool,
            newParams
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit IInventoryPool01.ParamsContractUpgraded(newParams);
        accessManager.upgradeParamsContract(wethInventoryPool, newParams, signatures);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_upgradeParamsContract_onlyCallableByAdmin() public {
        OwnableParams01 newParams = new OwnableParams01(
            defaultBaseFee,
            defaultRate1,
            defaultPenaltyRate,
            defaultPenaltyPeriod,
            address(accessManager)
        );

        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.upgradeParamsContract(wethInventoryPool, newParams, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_upgradeParamsContract_nonValidatorSignatureReverts() public {
        OwnableParams01 newParams = new OwnableParams01(
            defaultBaseFee,
            defaultRate1,
            defaultPenaltyRate,
            defaultPenaltyPeriod,
            address(accessManager)
        );

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.UPGRADE_PARAMS_CONTRACT_TYPEHASH(),
            wethInventoryPool,
            newParams
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.upgradeParamsContract(wethInventoryPool, newParams, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_overwriteCoreState_success() public {
        uint storedAccInterestFactor = 100;
        uint lastAccumulatedInterestUpdate = 200;
        uint scaledReceivables = 300;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.OVERWRITE_CORE_STATE_TYPEHASH(),
            wethInventoryPool,
            storedAccInterestFactor,
            lastAccumulatedInterestUpdate,
            scaledReceivables
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        accessManager.overwriteCoreState(
            wethInventoryPool,
            storedAccInterestFactor,
            lastAccumulatedInterestUpdate,
            scaledReceivables,
            signatures
        );
        assertEq(wethInventoryPool.storedAccInterestFactor(), storedAccInterestFactor);
        assertEq(wethInventoryPool.lastAccumulatedInterestUpdate(), lastAccumulatedInterestUpdate);
        assertEq(wethInventoryPool.scaledReceivables(), scaledReceivables);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_overwriteCoreState_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.overwriteCoreState(wethInventoryPool, 100, 200, block.timestamp, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_overwriteCoreState_nonValidatorSignatureReverts() public {
        uint storedAccInterestFactor = 100;
        uint lastAccumulatedInterestUpdate = 200;
        uint scaledReceivables = 300;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.OVERWRITE_CORE_STATE_TYPEHASH(),
            wethInventoryPool,
            storedAccInterestFactor,
            lastAccumulatedInterestUpdate,
            scaledReceivables
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.overwriteCoreState(wethInventoryPool, storedAccInterestFactor, lastAccumulatedInterestUpdate, scaledReceivables, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_transferOwnership_success() public {
        address newOwner = address(0x123);
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.TRANSFER_OWNERSHIP_TYPEHASH(),
            wethInventoryPool,
            newOwner
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(address(accessManager), newOwner);
        accessManager.transferOwnership(wethInventoryPool, newOwner, signatures);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_transferOwnership_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.transferOwnership(wethInventoryPool, address(0x123), new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_transferOwnership_nonValidatorSignatureReverts() public {
        address newOwner = address(0x123);
        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.TRANSFER_OWNERSHIP_TYPEHASH(),
            wethInventoryPool,
            newOwner
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.transferOwnership(wethInventoryPool, newOwner, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_addValidator_success() public {
        address newValidator = address(0x456);
        uint16 newSignatureThreshold = 3;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.ADD_VALIDATOR_TYPEHASH(),
            newValidator,
            newSignatureThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        accessManager.addValidator(newValidator, newSignatureThreshold, signatures);
        vm.stopPrank();

        assertTrue(accessManager.hasRole(VALIDATOR_ROLE, newValidator), "New validator should have validator role");
        assertEq(accessManager.validatorCount(), 4, "Validator count should be incremented");
        assertEq(accessManager.signatureThreshold(), newSignatureThreshold, "Signature threshold should be updated");
    }

    function testInventoryPoolDefaultAccessManager01_addValidator_onlyCallableByAdmin() public {
        address newValidator = address(0x456);
        uint16 newSignatureThreshold = 3;

        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.addValidator(newValidator, newSignatureThreshold, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_addValidator_existingValidatorReverts() public {
        uint16 newSignatureThreshold = 3;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.ADD_VALIDATOR_TYPEHASH(),
            validator1,
            newSignatureThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(InventoryPoolDefaultAccessManager01.ValidatorExists.selector, validator1));
        accessManager.addValidator(validator1, newSignatureThreshold, signatures);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_addValidator_nonValidatorSignatureReverts() public {
        address newValidator = address(0x456);
        uint16 newSignatureThreshold = 3;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.ADD_VALIDATOR_TYPEHASH(),
            newValidator,
            newSignatureThreshold
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.addValidator(newValidator, newSignatureThreshold, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_removeValidator_success() public {
        uint16 newSignatureThreshold = 2;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.REMOVE_VALIDATOR_TYPEHASH(),
            validator3,
            newSignatureThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        accessManager.removeValidator(validator3, newSignatureThreshold, signatures);
        vm.stopPrank();

        assertFalse(accessManager.hasRole(VALIDATOR_ROLE, validator3), "Removed validator should not have validator role");
        assertEq(accessManager.validatorCount(), 2, "Validator count should be decremented");
        assertEq(accessManager.signatureThreshold(), newSignatureThreshold, "Signature threshold should be updated");
    }

    function testInventoryPoolDefaultAccessManager01_removeValidator_onlyCallableByAdmin() public {
        uint16 newSignatureThreshold = 2;

        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.removeValidator(validator2, newSignatureThreshold, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_removeValidator_nonValidatorReverts() public {
        address nonValidator = address(0x789);
        uint16 newSignatureThreshold = 2;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.REMOVE_VALIDATOR_TYPEHASH(),
            nonValidator,
            newSignatureThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(InventoryPoolDefaultAccessManager01.ValidatorDoesNotExist.selector, nonValidator));
        accessManager.removeValidator(nonValidator, newSignatureThreshold, signatures);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_removeValidator_nonValidatorSignatureReverts() public {
        uint16 newSignatureThreshold = 2;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.REMOVE_VALIDATOR_TYPEHASH(),
            validator3,
            newSignatureThreshold
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.removeValidator(validator3, newSignatureThreshold, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_removeValidator_lastValidatorReverts() public {
        // Setup: Create a contract with just one validator
        address[] memory singleValidator = new address[](1);
        singleValidator[0] = validator1;
        InventoryPoolDefaultAccessManager01 singleValidatorContract = new InventoryPoolDefaultAccessManager01(
            admin,
            singleValidator,
            1
        );

        // Create signature for removing the validator
        bytes32 digest = singleValidatorContract.hashTypedData(
            keccak256(abi.encode(
                singleValidatorContract.REMOVE_VALIDATOR_TYPEHASH(),
                validator1,
                uint16(1)
            ))
        );

        uint256[] memory privKeys = new uint256[](1);
        privKeys[0] = validator1_pk;
        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // Attempt to remove the last validator
        vm.prank(admin);
        vm.expectRevert(InventoryPoolDefaultAccessManager01.ZeroValidatorsNotAllowed.selector);
        singleValidatorContract.removeValidator(validator1, 1, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_setSignatureThreshold_success() public {
        uint16 newSignatureThreshold = 3;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.SET_SIGNATURE_THRESHOLD_TYPEHASH(),
            newSignatureThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit InventoryPoolDefaultAccessManager01.SignatureThresholdUpdated(newSignatureThreshold);
        accessManager.setSignatureThreshold(newSignatureThreshold, signatures);
        vm.stopPrank();

        assertEq(accessManager.signatureThreshold(), newSignatureThreshold, "Signature threshold should be updated");
    }

    function testInventoryPoolDefaultAccessManager01_setSignatureThreshold_onlyCallableByAdmin() public {
        uint16 newSignatureThreshold = 3;

        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.setSignatureThreshold(newSignatureThreshold, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_setSignatureThreshold_nonValidatorSignatureReverts() public {
        uint16 newSignatureThreshold = 3;

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.SET_SIGNATURE_THRESHOLD_TYPEHASH(),
            newSignatureThreshold
        )));

        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = 0x999; // Random private key for non-validator
        address nonValidator = vm.addr(privKeys[1]);

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonValidator, VALIDATOR_ROLE));
        accessManager.setSignatureThreshold(newSignatureThreshold, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_setSignatureThreshold_tooHighReverts() public {
        uint16 tooHighThreshold = uint16(validators.length + 1); // 4, which is greater than validator count of 3

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.SET_SIGNATURE_THRESHOLD_TYPEHASH(),
            tooHighThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(
            InventoryPoolDefaultAccessManager01.SignatureThresholdTooHigh.selector,
            tooHighThreshold,
            validators.length
        ));
        accessManager.setSignatureThreshold(tooHighThreshold, signatures);
    }

    function testInventoryPoolDefaultAccessManager01_setSignatureThreshold_tooLowReverts() public {
        uint16 tooLowThreshold = uint16(validators.length / 2); // 1, which is <= half of validator count

        bytes32 digest = accessManager.hashTypedData(keccak256(abi.encode(
            accessManager.SET_SIGNATURE_THRESHOLD_TYPEHASH(),
            tooLowThreshold
        )));
        bytes[] memory signatures = getValidatorSignatures(digest);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(
            InventoryPoolDefaultAccessManager01.SignatureThresholdTooLow.selector,
            tooLowThreshold,
            validators.length
        ));
        accessManager.setSignatureThreshold(tooLowThreshold, signatures);
    }

    // Role management tests
    function testInventoryPoolDefaultAccessManager01_grantRole_reverts() public {
        vm.startPrank(admin);
        vm.expectRevert(InventoryPoolDefaultAccessManager01.GrantRoleNotAllowed.selector);
        accessManager.grantRole(VALIDATOR_ROLE, address(0x123));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_revokeRole_reverts() public {
        vm.startPrank(admin);
        vm.expectRevert(InventoryPoolDefaultAccessManager01.RevokeRoleNotAllowed.selector);
        accessManager.revokeRole(VALIDATOR_ROLE, validator1);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_renounceRole_reverts() public {
        vm.startPrank(validator1);
        vm.expectRevert(InventoryPoolDefaultAccessManager01.RenounceRoleNotAllowed.selector);
        accessManager.renounceRole(VALIDATOR_ROLE, validator1);
        vm.stopPrank();
    }

    // Helper function to get 2 validator signatures
    function getValidatorSignatures(bytes32 digest) internal pure returns (bytes[] memory) {
        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = validator2_pk;
        return getSignaturesFromKeys(digest, privKeys);
    }
}
