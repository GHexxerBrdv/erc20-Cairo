# ERC20 (Starknet)

A Cairo smart contract implementing a fungible token on [Starknet](https://www.starknet.io/), with the usual ERC-20-style surface area plus owner-gated mint and burn.

## Features

- **Metadata**: `name`, `symbol`, and `decimals` (set in the constructor).
- **Balances and supply**: `balance_of`, `total_supply`.
- **Allowances**: `approve`, `allowance`, `transfer_from`.
- **Transfers**: `transfer` with balance checks.
- **Events**: `Transfer` and `Approval` (Starknet events).
- **Admin**: `mint` and `burn` are restricted to the address passed as `owner` in the constructor.

Default token metadata in this implementation: **GB_Token** (`GB-53F8`), **18** decimals.

## Requirements

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo/Starknet package manager)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) (`snforge`) for tests

Versions used in this repo (see `Scarb.toml`): `starknet` **2.16.0**, `snforge_std` **0.57.0**.

## Build

```bash
scarb build
```

Compiled Starknet artifacts are emitted under `target/dev/` when the `starknet-contract` target is enabled.

## Tests

```bash
scarb test
```

This runs the `test` script defined in `Scarb.toml`, which invokes `snforge test`. Integration tests live in `tests/test_contract.cairo` and cover constructor metadata, mint/supply, `transfer`, `approve`, `transfer_from`, and failure cases for insufficient balance or allowance.

## Contract layout

| Item | Location |
|------|----------|
| `IERC20` interface and `ERC20` contract | `src/lib.cairo` |
| Snforge tests | `tests/test_contract.cairo` |
| Package manifest | `Scarb.toml` |
| Foundry config | `snfoundry.toml` |

The constructor takes a single argument: `owner: ContractAddress`. Only that address may call `mint` and `burn`.

