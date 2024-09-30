// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "pancake-v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "pancake-v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLBaseHook} from "./CLBaseHook.sol";

import {LPFeeLibrary} from "pancake-v4-core/src/libraries/LPFeeLibrary.sol";

contract FreeSwapHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint24) public poolToLpFee;

    mapping(uint24 => uint256) public discountTiers0;
    mapping(uint24 => uint256) public discountTiers1;
    mapping(uint24 => uint24) public discountPercentages;

    event LogFeeUpdated(uint24 lpFee);

    constructor(ICLPoolManager _poolManager) CLBaseHook(_poolManager) {
        discountTiers0[0] = 0;
        discountTiers0[1] = 1000;
        discountTiers0[2] = 50000;
        discountTiers0[3] = 100000;
        discountTiers0[4] = 5000000;

        // Thresholds for token1
        discountTiers1[0] = 0;
        discountTiers1[1] = 1000;
        discountTiers1[2] = 50000;
        discountTiers1[3] = 100000;
        discountTiers1[4] = 5000000;

        // Discount percentages for each tier
        discountPercentages[0] = 0;
        discountPercentages[1] = 20;
        discountPercentages[2] = 30;
        discountPercentages[3] = 40;
        discountPercentages[4] = 50;
    }

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnsDelta: false,
                afterSwapReturnsDelta: false,
                afterAddLiquidityReturnsDelta: false,
                afterRemoveLiquidityReturnsDelta: false
            })
        );
    }

    function afterInitialize(address, PoolKey calldata key, uint160, int24, bytes calldata hookData)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        uint24 lpFee = abi.decode(hookData, (uint24));
        poolToLpFee[key.toId()] = lpFee;

        return this.afterInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata swapParams, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 lpFee = poolToLpFee[key.toId()];
        uint24 maxDiscount = 50; // 50% max discount

        uint256 amountAbs =
            swapParams.amountSpecified > 0 ? uint256(swapParams.amountSpecified) : uint256(-swapParams.amountSpecified);

        // Determine which token is being swapped in
        bool isToken0In = swapParams.zeroForOne == (swapParams.amountSpecified > 0);

        uint24 appliedDiscount = 0;

        for (uint24 i = 4; i >= 0; i--) {
            if (amountAbs >= (isToken0In ? discountTiers0[i] : discountTiers1[i])) {
                appliedDiscount = discountPercentages[i];
                break;
            }
        }

        // Apply the discount, but cap it at the max discount
        uint24 actualDiscount = appliedDiscount > maxDiscount ? maxDiscount : appliedDiscount;
        lpFee = lpFee * (100 - actualDiscount) / 100;

        emit LogFeeUpdated(lpFee);

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, lpFee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }
}
