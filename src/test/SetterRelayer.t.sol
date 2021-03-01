pragma solidity 0.6.7;

import "ds-test/test.sol";

import "../mock/MockOracleRelayer.sol";
import "../mock/MockTreasury.sol";

import "../SetterRelayer.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}
contract User {
    function relayRate(SetterRelayer relayer, uint256 redemptionRate) external {
        relayer.relayRate(redemptionRate);
    }
}

contract SetterRelayerTest is DSTest {
    Hevm hevm;

    User user;
    MockOracleRelayer oracleRelayer;

    SetterRelayer setterRelayer;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        user = new User();

        oracleRelayer = new MockOracleRelayer();
        setterRelayer = new SetterRelayer(address(oracleRelayer));

        setterRelayer.modifyParameters("setter", address(this));
    }

    function test_setup() public {
        assertTrue(setterRelayer.setter() == address(this));
        assertTrue(address(setterRelayer.oracleRelayer()) == address(oracleRelayer));
        assertEq(setterRelayer.authorizedAccounts(address(this)), 1);
    }
    function test_modifyParameters() public {
        setterRelayer.modifyParameters("setter", address(0x1));
        assertTrue(setterRelayer.setter() == address(0x1));
    }
    function testFail_modifyParameters() public {
        setterRelayer.modifyParameters("setter", address(0));
    }
    function testFail_relay_rate_by_unauthed() public {
        user.relayRate(setterRelayer, 5E27);
    }
    function test_relay_rate_twice() public {
        setterRelayer.relayRate(5E27);
        assertEq(oracleRelayer.redemptionRate(), 5E27);
    }
}
