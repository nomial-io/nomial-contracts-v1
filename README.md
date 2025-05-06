[![Tests](https://github.com/nomial-io/nomial-contracts-v1/actions/workflows/ci.yml/badge.svg)](https://github.com/nomial-io/nomial-contracts-v1/actions/workflows/ci.yml)

# Nomial Contracts v1

Nomial V1 is a protocol for crosschain inventory access, designed for intent solvers. It allows solvers to deposit ERC20 tokens as collateral on a single chain and borrow against this collateral on multiple chains.

## Overview

The Nomial V1 protocol facilitates crosschain inventory access through two main components:
1. **CollateralPool** - A single contract where solvers deposit ERC20 tokens as collateral.
2. **InventoryPools** - Multiple lending pools deployed across different chains, where Liquidity Providers (LPs) can deposit assets and earn interest from borrowers (solvers)

## Architecture

### CollateralPool

[CollateralPool01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/CollateralPool01.sol)

- Accepts collateral deposits of any ERC20 token from solvers
- Implements a time-locked withdrawal mechanism to allow time for liquidations
- Has a two-step withdrawal process with configurable withdrawal period
- Allows an owner EOA or contract to liquidate solver balances and pending withdrawals

### InventoryPools

[InventoryPool01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/InventoryPool01.sol)

- An [ERC-4626](https://docs.openzeppelin.com/contracts/5.x/erc4626) token vault deployed on chains where solver inventory is needed
- Each pool manages a single ERC20 asset
- Interest paid by borrowers accrues proportionally to depositors in the vault
- Penalty interest is incurred for overdue loans, to disincentivize long-term borrowing and incentivize borrowers to move assets back to the chain where the pool is deployed
- Supports dynamic interest rate and penalty rate models through the [IInventoryPoolParams01](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/interfaces/IInventoryPoolParams01.sol) interface


### Interest Rate Models

Nomial V1 has two interest rate model implementations

#### OwnableParams01

[OwnableParams01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/OwnableParams01.sol)

Allows an owner EOA or contract to set interest and penalty rate parameters. This allows for flexible, off-chain interest rate modeling that can be adjusted as needed.

#### UtilizationBasedRateParams01

[UtilizationBasedRateParams01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/UtilizationBasedRateParams01.sol)

This models Aave V3’s default [Interest Rate Strategy](https://aave.com/docs/developers/smart-contracts/interest-rate-strategy), which is a 2-slope formula with an optimal utilization ratio. 


## Security Model

All Nomial V1 core contracts implement the simplest form of access control, [OpenZeppelin Ownable](https://docs.openzeppelin.com/contracts/5.x/access-control#ownership-and-ownable). This allows for more powerful access control models to be plugged in as needed.

Nomial V1 has a default access control model, intended to be set as owner for all core contracts.

#### InventoryPoolDefaultAccessManager01

[InventoryPoolDefaultAccessManager01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/owners/InventoryPoolDefaultAccessManager01.sol)

The default access manager extends [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/5.x/api/access#AccessControl) to add `VALIDATOR_ROLE` and `BORROWER_ROLE`, in addition to `DEFAULT_ADMIN_ROLE`.

All operations explicitly require the default admin to execute with the required threshold of validator signatures. In other words, the admin cannot execute any operation without sign-off from validators.

The one exception is the [borrow()](https://github.com/nomial-io/nomial-contracts-v1/blob/89ac640c332d06cebf92a9ea22b23a8733bdd501/src/owners/InventoryPoolDefaultAccessManager01.sol#L92) operation. This can be executed by any address with `BORROWER_ROLE`, with the required threshold of validator signatures.

InventoryPoolDefaultAccessManager01 works with [CollateralPool01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/CollateralPool01.sol), [InventoryPool01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/InventoryPool01.sol), and [OwnableParams01.sol](https://github.com/nomial-io/nomial-contracts-v1/blob/main/src/OwnableParams01.sol).

## Development

### Build
```bash
yarn install
forge build
```

### Testing
```bash
forge test
```

## License

GPL-3.0-or-later

