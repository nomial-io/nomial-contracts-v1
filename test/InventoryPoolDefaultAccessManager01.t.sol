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

    // Helper function to get 2 validator signatures
    function getValidatorSignatures(bytes32 digest) internal pure returns (bytes[] memory) {
        bytes[] memory signatures = new bytes[](2);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(validator1_pk, digest);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(validator2_pk, digest);
        signatures[0] = abi.encodePacked(r1, s1, v1);
        signatures[1] = abi.encodePacked(r2, s2, v2);
        return signatures;
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

    function testInventoryPoolDefaultAccessManager01_updateInterestRate_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updateInterestRate(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyRate_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updatePenaltyRate(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updatePenaltyPeriod_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updatePenaltyPeriod(ownableParams, 100, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_forgiveDebt_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.forgiveDebt(wethInventoryPool, 1 * 10**18, borrower, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_updateBaseFee_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.updateBaseFee(ownableParams, 100, new bytes[](0));
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

    function testInventoryPoolDefaultAccessManager01_overwriteCoreState_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.overwriteCoreState(wethInventoryPool, 100, 200, block.timestamp, new bytes[](0));
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_transferOwnership_onlyCallableByAdmin() public {
        vm.startPrank(validator1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, validator1, accessManager.DEFAULT_ADMIN_ROLE()));
        accessManager.transferOwnership(wethInventoryPool, address(0x123), new bytes[](0));
        vm.stopPrank();
    }
}
