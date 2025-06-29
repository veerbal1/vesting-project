# Vesting Wallet Project

A smart contract implementation for token vesting with time-based release schedules. Built with Solidity and Foundry.

## Overview

This project implements a vesting wallet system that allows tokens to be locked and gradually released to beneficiaries according to a predefined schedule. It's useful for team token allocations, investor distributions, and other scenarios requiring controlled token release.

## Features

- Time-based vesting schedule
- ERC20 token support
- Secure access control
- Configurable vesting parameters

## Smart Contracts

- `VestToken.sol`: An ERC20 token used for demonstration purposes
- `VestingWallet.sol`: The main vesting contract that handles token lockup and release

## Development

This project is built using [Foundry](https://book.getfoundry.sh/), a blazing fast Ethereum development toolkit.

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/veerbal1/vesting-project.git
cd vesting-project
```

2. Install dependencies:
```bash
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Gas Snapshots

```bash
forge snapshot
```

## License

MIT

## Author

Veerbal Singh
