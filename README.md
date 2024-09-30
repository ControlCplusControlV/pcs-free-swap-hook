# FreeSwapHook

FreeSwapHook is a custom hook for Pancakeswap v4's concentrated liquidity pools. It implements a dynamic fee discount system based on the swap amount, encouraging larger trades by offering reduced fees.

## Overview

This hook modifies the standard fee structure of Pancakeswap v4 pools by introducing a tiered discount system. The discount applied depends on the size of the swap, with larger swaps receiving more significant fee reductions.

## Features

- Dynamic fee discounts based on swap amount
- Support for both token0 and token1 swaps
- Discounts capped at 50% of the base fee
- Customizable thresholds for different discount tiers

## Fee Discount Tiers

The hook implements the following discount tiers:

| Swap Amount (x = threshold) | Fee Discount |
|---------------------------|--------------|
| < x                       | 0% (base fee) |
| x to 5x                   | 20%          |
| 5x to 10x                 | 30%          |
| 10x to 50x                | 40%          |
| > 50x                     | 50% (max)    |

The threshold (x) is set to 1000 units for token0 and 5000 units for token1.

## Usage

1. Deploy the FreeSwapHook contract, passing the address of the Pancakeswap v4 PoolManager.
2. Create a PoolKey using the FreeSwapHook address as the `hooks` parameter.
3. Initialize the pool with the desired base fee (e.g., 0.3% or 3000 in Pancakeswap's fee representation).
4. Users interacting with this pool will automatically benefit from the dynamic fee discount system.

## Testing

The provided test file (`FreeSwapHookTest.sol`) includes comprehensive tests for various swap amounts and their corresponding fee discounts. To run the tests:

1. Ensure you have Forge installed.
2. Run `forge test` in the project directory.

## Dependencies

- Pancakeswap v4 core and periphery contracts
- Forge Standard Library (for testing)

## License

This project is licensed under the MIT license.

## Disclaimer

This hook is provided as-is. Make sure to thoroughly test and audit the code before using it in a production environment. The developers are not responsible for any losses incurred from the use of this software.
