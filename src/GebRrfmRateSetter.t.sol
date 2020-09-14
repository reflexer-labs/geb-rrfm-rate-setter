pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebRrfmRateSetter.sol";

contract GebRrfmRateSetterTest is DSTest {
    GebRrfmRateSetter setter;

    function setUp() public {
        setter = new GebRrfmRateSetter();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
