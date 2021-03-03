pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../mock/MockOracleRelayer.sol";
import "../mock/MockTreasury.sol";

import "../SetterRelayer.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}
contract User {
    function relayRate(SetterRelayer relayer, uint256 redemptionRate, address feeReceiver) external {
        relayer.relayRate(redemptionRate, feeReceiver);
    }
}

contract SetterRelayerTest is DSTest {
    Hevm hevm;

    User user;
    DSToken systemCoin;

    MockOracleRelayer oracleRelayer;
    MockTreasury treasury;

    SetterRelayer setterRelayer;

    uint256 relayDelay = 3600;
    uint256 baseUpdateCallerReward = 5E18;
    uint256 maxUpdateCallerReward  = 10E18;
    uint256 maxRewardIncreaseDelay = 4 hours;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% per hour

    uint256 coinsToMint = 1E40;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        user          = new User();

        systemCoin    = new DSToken("RAI", "RAI");

        oracleRelayer = new MockOracleRelayer();
        treasury      = new MockTreasury(address(systemCoin));
        setterRelayer = new SetterRelayer(
          address(oracleRelayer),
          address(treasury),
          baseUpdateCallerReward,
          maxUpdateCallerReward,
          perSecondCallerRewardIncrease,
          relayDelay
        );

        systemCoin.mint(address(treasury), coinsToMint);

        setterRelayer.modifyParameters("setter", address(this));
        setterRelayer.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        treasury.setTotalAllowance(address(setterRelayer), uint(-1));
        treasury.setPerBlockAllowance(address(setterRelayer), uint(-1));
    }

    function test_setup() public {
        assertTrue(setterRelayer.setter() == address(this));
        assertTrue(address(setterRelayer.oracleRelayer()) == address(oracleRelayer));
        assertEq(setterRelayer.authorizedAccounts(address(this)), 1);

        assertEq(setterRelayer.baseUpdateCallerReward(), baseUpdateCallerReward);
        assertEq(setterRelayer.maxUpdateCallerReward(), maxUpdateCallerReward);
        assertEq(setterRelayer.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease);
        assertEq(setterRelayer.relayDelay(), relayDelay);
        assertEq(setterRelayer.maxRewardIncreaseDelay(), maxRewardIncreaseDelay);
    }
    function test_modifyParameters() public {
        MockTreasury newTreasury = new MockTreasury(address(systemCoin));

        setterRelayer.modifyParameters("setter", address(0x1));
        setterRelayer.modifyParameters("treasury", address(newTreasury));

        setterRelayer.modifyParameters("baseUpdateCallerReward", baseUpdateCallerReward + 1);
        setterRelayer.modifyParameters("maxUpdateCallerReward", maxUpdateCallerReward + 1);
        setterRelayer.modifyParameters("perSecondCallerRewardIncrease", perSecondCallerRewardIncrease + 1);
        setterRelayer.modifyParameters("relayDelay", relayDelay + 1);
        setterRelayer.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay + 1);

        assertTrue(setterRelayer.setter() == address(0x1));
        assertTrue(address(setterRelayer.treasury()) == address(newTreasury));

        assertEq(setterRelayer.baseUpdateCallerReward(), baseUpdateCallerReward + 1);
        assertEq(setterRelayer.maxUpdateCallerReward(), maxUpdateCallerReward + 1);
        assertEq(setterRelayer.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease + 1);
        assertEq(setterRelayer.relayDelay(), relayDelay + 1);
        assertEq(setterRelayer.maxRewardIncreaseDelay(), maxRewardIncreaseDelay + 1);
    }
    function testFail_modifyParameters() public {
        setterRelayer.modifyParameters("setter", address(0));
    }
    function testFail_relay_rate_by_unauthed() public {
        user.relayRate(setterRelayer, 5E27, address(0x12));
    }
    function test_relay_rate_twice() public {
        setterRelayer.relayRate(1E27 + 10, address(0x12));
        assertEq(oracleRelayer.redemptionRate(), 1E27 + 10);
        assertEq(systemCoin.balanceOf(address(0x12)), baseUpdateCallerReward);
        hevm.warp(now + relayDelay);
        setterRelayer.relayRate(8E27, address(0x12));
        assertEq(oracleRelayer.redemptionRate(), 8E27);
        assertEq(systemCoin.balanceOf(address(0x12)), baseUpdateCallerReward * 2);
    }
    function test_relay_after_long_break() public {
        setterRelayer.relayRate(1E27 + 10, address(0x12));
        assertEq(oracleRelayer.redemptionRate(), 1E27 + 10);
        assertEq(systemCoin.balanceOf(address(0x12)), baseUpdateCallerReward);
        hevm.warp(now + relayDelay * 10);
        setterRelayer.relayRate(8E27, address(0x12));
        assertEq(oracleRelayer.redemptionRate(), 8E27);
        assertEq(systemCoin.balanceOf(address(0x12)), baseUpdateCallerReward + maxUpdateCallerReward);
    }
}
