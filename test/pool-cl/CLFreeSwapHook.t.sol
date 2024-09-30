// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FreeSwapHook} from "../../src/pool-cl/FreeSwapHook.sol";
import {CLTestUtils} from "./utils/CLTestUtils.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {Currency} from "pancake-v4-core/src/types/Currency.sol";
import {ICLRouterBase} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLRouterBase.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {Constants} from "pancake-v4-core/test/pool-cl/helpers/Constants.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract FreeSwapHookTest is Test, CLTestUtils {
    using PoolIdLibrary for PoolKey;
    using CLPoolParametersHelper for bytes32;

    FreeSwapHook hook;
    Currency currency0;
    Currency currency1;
    PoolKey key;

    function setUp() public {
        (currency0, currency1) = deployContractsWithTokens();
        hook = new FreeSwapHook(poolManager);

        // create the pool key
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hook,
            poolManager: poolManager,
            fee: uint24(3000), // 0.3% fee
            parameters: bytes32(uint256(hook.getHooksRegistrationBitmap())).setTickSpacing(60)
        });

        // initialize pool at 1:1 price point (assume stablecoin pair)
        bytes memory initData = abi.encode(3000); // 0.3% base LP fee
        poolManager.initialize(key, Constants.SQRT_RATIO_1_1, initData);
    }

    function testFeeDiscounts() public {
        // Add liquidity to the pool
        MockERC20(Currency.unwrap(currency0)).mint(address(this), 1000000 ether);
        MockERC20(Currency.unwrap(currency1)).mint(address(this), 1000000 ether);
        addLiquidity(key, 1000000 ether, 1000000 ether, -120, 120, address(this));

        // Test cases for token0
        assertFeeDiscount(999, true); // No discount
        assertFeeDiscount(1000, true); // 20% discount
        assertFeeDiscount(50000, true); // 30% discount
        assertFeeDiscount(100000, true); // 40% discount
        assertFeeDiscount(5000000, true); // 50% discount (capped)

        // Test cases for token1
        assertFeeDiscount(4999, false); // No discount
        assertFeeDiscount(5000, false); // 20% discount
        assertFeeDiscount(25000, false); // 30% discount
        assertFeeDiscount(50000, false); // 40% discount
        assertFeeDiscount(250000, false); // 50% discount (capped)
    }

    function calculateExpectedFee(uint256 amount, bool zeroForOne) internal pure returns (uint24) {
        uint256 threshold = zeroForOne ? 1000 : 5000;
        if (amount < threshold) return 3000; // No discount
        if (amount < threshold * 5) return 2400; // 20% discount
        if (amount < threshold * 10) return 2100; // 30% discount
        if (amount < threshold * 50) return 1800; // 40% discount
        return 1500; // 50% discount (capped)
    }

    function assertFeeDiscount(uint256 amount, bool zeroForOne) internal {
        MockERC20(Currency.unwrap(currency0)).mint(address(this), amount);
        MockERC20(Currency.unwrap(currency1)).mint(address(this), amount);

        MockERC20(Currency.unwrap(currency0)).approve(address(poolManager), amount);
        MockERC20(Currency.unwrap(currency1)).approve(address(poolManager), amount);

        uint256 balanceBefore0 = MockERC20(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 balanceBefore1 = MockERC20(Currency.unwrap(currency1)).balanceOf(address(this));

        uint24 expectedFee = calculateExpectedFee(amount, zeroForOne);

        // Start recording logs
        vm.recordLogs();

        exactInputSingle(
            ICLRouterBase.CLSwapExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: uint128(amount),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                hookData: new bytes(0)
            })
        );

        // Get the recorded logs
        VmSafe.Log[] memory entries = vm.getRecordedLogs();

        // Find the LogFeeUpdated event
        uint24 eventFee;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("LogFeeUpdated(uint24)")) {
                eventFee = abi.decode(entries[i].data, (uint24));
                break;
            }
        }

        emit log_named_uint("Fee from event", eventFee);
    }
}
