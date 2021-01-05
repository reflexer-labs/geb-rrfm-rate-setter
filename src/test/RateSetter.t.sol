pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {MockPIDCalculator} from '../mock/MockPIDCalculator.sol';
import {RateSetter} from "../RateSetter.sol";
import "../mock/MockOracleRelayer.sol";
import "../mock/MockTreasury.sol";

contract Feed {
    bytes32 public price;
    bool public validPrice;
    uint public lastUpdateTime;

    constructor(uint256 price_, bool validPrice_) public {
        price = bytes32(price_);
        validPrice = validPrice_;
        lastUpdateTime = now;
    }

    function updateTokenPrice(uint256 price_) external {
        price = bytes32(price_);
        lastUpdateTime = now;
    }
    function getResultWithValidity() external view returns (uint256, bool) {
        return (uint(price), validPrice);
    }
}
abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract RateSetterTest is DSTest {
    Hevm hevm;

    DSToken systemCoin;
    MockTreasury treasury;
    MockOracleRelayer oracleRelayer;
    RateSetter rateSetter;

    MockPIDCalculator calculator;
    Feed orcl;

    uint256 periodSize = 3600;
    uint256 baseUpdateCallerReward = 5E18;
    uint256 maxUpdateCallerReward  = 10E18;
    uint256 maxRewardIncreaseDelay = 4 hours;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% per hour

    uint256 coinsToMint = 1E40;

    uint RAY = 10 ** 27;
    uint WAD = 10 ** 18;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        systemCoin = new DSToken("RAI", "RAI");

        oracleRelayer = new MockOracleRelayer();
        orcl = new Feed(1 ether, true);
        treasury = new MockTreasury(address(systemCoin));

        systemCoin.mint(address(treasury), coinsToMint);

        calculator = new MockPIDCalculator();
        rateSetter = new RateSetter(
          address(oracleRelayer),
          address(orcl),
          address(treasury),
          address(calculator),
          baseUpdateCallerReward,
          maxUpdateCallerReward,
          perSecondCallerRewardIncrease,
          periodSize
        );
        rateSetter.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        treasury.setTotalAllowance(address(rateSetter), uint(-1));
        treasury.setPerBlockAllowance(address(rateSetter), uint(-1));
    }

    function test_correct_setup() public {
        assertEq(rateSetter.baseUpdateCallerReward(), baseUpdateCallerReward);
        assertEq(rateSetter.maxUpdateCallerReward(), maxUpdateCallerReward);
        assertEq(rateSetter.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease);
        assertEq(rateSetter.contractEnabled(), 1);
    }
    function test_modify_parameters() public {
        // Modify
        MockTreasury newTreasury = new MockTreasury(address(systemCoin));

        rateSetter.modifyParameters("orcl", address(0x12));
        rateSetter.modifyParameters("oracleRelayer", address(0x12));
        rateSetter.modifyParameters("treasury", address(newTreasury));
        rateSetter.modifyParameters("pidCalculator", address(0x12));

        rateSetter.modifyParameters("baseUpdateCallerReward", 1);
        rateSetter.modifyParameters("maxUpdateCallerReward", 2);
        rateSetter.modifyParameters("perSecondCallerRewardIncrease", RAY);
        rateSetter.modifyParameters("updateRateDelay", 1);

        // Check
        assertTrue(address(rateSetter.orcl()) == address(0x12));
        assertTrue(address(rateSetter.oracleRelayer()) == address(0x12));
        assertTrue(address(rateSetter.treasury()) == address(newTreasury));
        assertTrue(address(rateSetter.pidCalculator()) == address(0x12));

        assertEq(rateSetter.baseUpdateCallerReward(), 1);
        assertEq(rateSetter.maxUpdateCallerReward(), 2);
        assertEq(rateSetter.perSecondCallerRewardIncrease(), RAY);
        assertEq(rateSetter.updateRateDelay(), 1);
    }
    function test_disable() public {
        rateSetter.disableContract();
        assertEq(rateSetter.contractEnabled(), 0);
    }
    function test_get_redemption_and_market_prices() public {
        (uint marketPrice, uint redemptionPrice) = rateSetter.getRedemptionAndMarketPrices();
        assertEq(marketPrice, 1 ether);
        assertEq(redemptionPrice, RAY);
    }
    function test_first_update_rate_no_warp() public {
        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);
    }
    function test_first_update_rate_with_warp() public {
        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);
    }
    function testFail_update_before_period_passed() public {
        rateSetter.updateRate(address(0x123));
        rateSetter.updateRate(address(0x123));
    }
    function test_two_updates() public {
        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);

        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward * 2);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);
    }
    function test_null_rate_needed_submit_different() public {
        calculator.toggleValidated();
        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY - 2);

        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY - 2);
    }
    function test_wait_more_than_maxRewardIncreaseDelay_since_last_update() public {
        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);

        hevm.warp(now + periodSize * 100000 + 1);
        assertEq(now - rateSetter.lastUpdateTime() - rateSetter.updateRateDelay(), 359996401);
        assertTrue(now - rateSetter.lastUpdateTime() - rateSetter.updateRateDelay() > rateSetter.maxRewardIncreaseDelay());
        assertEq(rateSetter.getCallerReward(), maxUpdateCallerReward);

        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward + maxUpdateCallerReward);
    }
    function test_oracle_relayer_bounded_rate() public {
        oracleRelayer.modifyParameters("redemptionRateUpperBound", RAY + 1);
        oracleRelayer.modifyParameters("redemptionRateLowerBound", RAY - 1);

        rateSetter.updateRate(address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY + 1);

        calculator.toggleValidated();

        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY - 1);
    }
}
