// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {LPFeeLibrary} from "../../src/libraries/LPFeeLibrary.sol";
import {ProtocolFeeLibrary} from "../../src/libraries/ProtocolFeeLibrary.sol";

contract ProtocolFeeLibraryTest is Test, GasSnapshot {
    function test_getZeroForOneFee() public pure {
        uint24 fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE - 1) << 12 | ProtocolFeeLibrary.MAX_PROTOCOL_FEE;
        assertEq(ProtocolFeeLibrary.getZeroForOneFee(fee), uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE));
    }

    function test_fuzz_getZeroForOneFee(uint24 fee) public pure {
        assertEq(ProtocolFeeLibrary.getZeroForOneFee(fee), fee % 4096);
    }

    function test_getOneForZeroFee() public pure {
        uint24 fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE - 1) << 12 | ProtocolFeeLibrary.MAX_PROTOCOL_FEE;
        assertEq(ProtocolFeeLibrary.getOneForZeroFee(fee), uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE - 1));
    }

    function test_fuzz_getOneForZeroFee(uint24 fee) public pure {
        assertEq(ProtocolFeeLibrary.getOneForZeroFee(fee), fee >> 12);
    }

    function test_isValidProtocolFee_fee() public pure {
        uint24 fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE + 1) << 12 | ProtocolFeeLibrary.MAX_PROTOCOL_FEE;
        assertFalse(ProtocolFeeLibrary.validate(fee));

        fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE) << 12 | (ProtocolFeeLibrary.MAX_PROTOCOL_FEE + 1);
        assertFalse(ProtocolFeeLibrary.validate(fee));

        fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE + 1) << 12 | (ProtocolFeeLibrary.MAX_PROTOCOL_FEE + 1);
        assertFalse(ProtocolFeeLibrary.validate(fee));

        fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE) << 12 | ProtocolFeeLibrary.MAX_PROTOCOL_FEE;
        assertTrue(ProtocolFeeLibrary.validate(fee));

        fee = uint24(ProtocolFeeLibrary.MAX_PROTOCOL_FEE - 1) << 12 | ProtocolFeeLibrary.MAX_PROTOCOL_FEE - 1;
        assertTrue(ProtocolFeeLibrary.validate(fee));

        fee = uint24(0) << 12 | uint24(0);
        assertTrue(ProtocolFeeLibrary.validate(fee));
    }

    function testFuzz_isValid(uint24 fee) public pure {
        if ((fee >> 12 > ProtocolFeeLibrary.MAX_PROTOCOL_FEE) || (fee % 4096 > ProtocolFeeLibrary.MAX_PROTOCOL_FEE)) {
            assertFalse(ProtocolFeeLibrary.validate(fee));
        } else {
            assertTrue(ProtocolFeeLibrary.validate(fee));
        }
    }

    function test_calculateSwapFee() public pure {
        assertEq(
            ProtocolFeeLibrary.calculateSwapFee(
                ProtocolFeeLibrary.MAX_PROTOCOL_FEE, LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE
            ),
            LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE
        );
        assertEq(ProtocolFeeLibrary.calculateSwapFee(ProtocolFeeLibrary.MAX_PROTOCOL_FEE, 3000), 3997);
        assertEq(
            ProtocolFeeLibrary.calculateSwapFee(ProtocolFeeLibrary.MAX_PROTOCOL_FEE, 0),
            ProtocolFeeLibrary.MAX_PROTOCOL_FEE
        );
        assertEq(ProtocolFeeLibrary.calculateSwapFee(0, 0), 0);
        assertEq(ProtocolFeeLibrary.calculateSwapFee(0, 1000), 1000);
    }

    function test_fuzz_calculateSwapFee(uint16 protocolFee, uint24 lpFee) public pure {
        protocolFee = uint16(bound(protocolFee, 0, ProtocolFeeLibrary.MAX_PROTOCOL_FEE));
        lpFee = uint24(bound(lpFee, 0, LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE));
        uint24 swapFee = ProtocolFeeLibrary.calculateSwapFee(protocolFee, lpFee);
        // if lp fee is not the max, the swap fee should never be the max since the protocol fee is taken off first and then the lp fee is taken from the remaining amount
        if (lpFee < LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE) {
            assertLt(swapFee, LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE);
        }
        assertGe(swapFee, lpFee);

        uint256 expectedSwapFee = protocolFee
            + lpFee * uint256(LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE - protocolFee) / LPFeeLibrary.ONE_HUNDRED_PERCENT_FEE;
        assertEq(swapFee, uint24(expectedSwapFee));
    }
}
