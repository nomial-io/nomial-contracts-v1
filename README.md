# Nomial Contracts v1

Nomial V1 is a protocol for cross-chain inventory access, designed for intent solvers. It allows solvers to deposit ERC20 tokens as collateral on Arbitrum One and borrow against this collateral on multiple chains.

## Overview

The Nomial V1 protocol facilitates cross-chain inventory access through two main components:
1. **CollateralPool** - A single contract deployed on Arbitrum One where solvers deposit ERC20 tokens as collateral.
2. **InventoryPools** - Multiple lending pools deployed across different blockchains, where Liquidity Providers (LPs) can deposit tokens to earn interest.

## Architecture

### CollateralPool
- Accepts collateral deposits of any ERC20 token from solvers
- Implements a time-locked withdrawal mechanism to allow time for liquidations
- Has a two-step withdrawal process with configurable withdrawal period
- Allows the owner (a multisig) to liquidate solver balances and pending withdrawals
- Deployed on Arbitrum One blockchain

### InventoryPools
- Deployed on blockchains where solver inventory is needed
- Each pool manages a single token type
- Utilization-based interest rate model based on Aave V3
- Penalty interest is incurred for overdue loans, to disincentivize long-term borrowing


## Security Model

### Owner Permissions
Both CollateralPool and InventoryPools are controlled by a multisig smart account. This multisig has exclusive permissions to:
- Liquidate solver balances and pending withdrawals in the CollateralPool
- Initiate borrowing against solver collateral in InventoryPools
- Update parameters like withdrawal periods and interest rates

**Important**: All lending and liquidation operations are entirely controlled by the multisig owner. This is an intentional design choice for Nomial V1

### Cross-Chain Security

Multisig signers will provide signatures off-chain to solvers to initiate borrowing on their behalf.

- InventoryPools are deployed independently on different chains
- Chain ID verification ensures that multisig signed borrows are only valid on the correct chain
- Solver collateral remains on Arbitrum One while LP funds are deployed to InventoryPools on different chains

## Interest Rate Model

The protocol uses a two-slope interest rate model similar to Aave v3 to determine LP returns:
- Base rate applies to all utilization levels
- Rate1 scales linearly up to optimal utilization
- Rate2 scales linearly above optimal utilization
- Additional penalty rate for overdue loans is added on top of base rate

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

