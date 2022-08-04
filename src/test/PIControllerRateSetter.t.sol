pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {MockPIController} from '../mock/MockPIController.sol';
import {PIControllerRateSetter} from "../PIControllerRateSetter.sol";
import {SetterRelayer} from "../SetterRelayer.sol";

import "../mock/MockOracleRelayer.sol";
import "../mock/MockTreasury.sol";
import "geb-treasury-reimbursement/math/GebMath.sol";
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

contract PIRateSetterTest is DSTest {
    Hevm hevm;

    DSToken systemCoin;
    MockTreasury treasury;
    MockOracleRelayer oracleRelayer;

    PIControllerRateSetter rateSetter;
    SetterRelayer setterRelayer;

    MockPIController controller;
    uint256 noiseBarrier = 0E27;
    Feed orcl;

    uint256 periodSize = 360;
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

        controller    = new MockPIController();
        noiseBarrier = WAD;
        setterRelayer = new SetterRelayer(
          address(oracleRelayer),
          address(treasury),
          baseUpdateCallerReward,
          maxUpdateCallerReward,
          perSecondCallerRewardIncrease,
          periodSize
        );
        rateSetter    = new PIControllerRateSetter(
          address(oracleRelayer),
          address(setterRelayer),
          address(orcl),
          address(controller),
          noiseBarrier,
          periodSize
        );

        setterRelayer.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);
        setterRelayer.modifyParameters("setter", address(rateSetter));

        treasury.setTotalAllowance(address(setterRelayer), uint(-1));
        treasury.setPerBlockAllowance(address(setterRelayer), uint(-1));
    }
    function test_correct_setup() public {
        assertEq(rateSetter.authorizedAccounts(address(this)), 1);
        assertEq(rateSetter.updateRateDelay(), periodSize);
    }
    function test_modify_parameters() public {
        // Modify
        rateSetter.modifyParameters("orcl", address(0x12));
        rateSetter.modifyParameters("oracleRelayer", address(0x13));
        rateSetter.modifyParameters("piController", address(0x14));
        rateSetter.modifyParameters("updateRateDelay", 1);

        // Check
        assertTrue(address(rateSetter.orcl()) == address(0x12));
        assertTrue(address(rateSetter.oracleRelayer()) == address(0x13));
        assertTrue(address(rateSetter.piController()) == address(0x14));

        assertEq(rateSetter.updateRateDelay(), 1);
    }
    function test_get_redemption_and_market_prices() public {
        (uint marketPrice, uint redemptionPrice) = rateSetter.getRedemptionAndMarketPrices();
        assertEq(marketPrice, 1 ether);
        assertEq(redemptionPrice, RAY);
    }
    function test_get_bounded_redemption_rate() public {
        int zeroOutput = 0E27;
        uint rate = rateSetter.getBoundedRedemptionRate(zeroOutput);
        assertEq(1E27, int(rate));

        int smallPosOutput = 0.00000000001E27;
        rate = rateSetter.getBoundedRedemptionRate(smallPosOutput);
        assertEq(1E27 + smallPosOutput, int(rate));

        int smallNegOutput = -0.00000000001E27;
        rate = rateSetter.getBoundedRedemptionRate(smallNegOutput);
        assertEq(1E27 + smallNegOutput, int(rate));
    }
    function test_get_bounded_redemption_rate_limit() public {
        int output = -1E27 + 2; 
        uint rate = rateSetter.getBoundedRedemptionRate(output);
        assertEq(rate, 2);

        output = -1E27 + 1; 
        rate = rateSetter.getBoundedRedemptionRate(output);
        assertEq(rate, 1);

        output = -1E27; 
        rate = rateSetter.getBoundedRedemptionRate(output);
        assertEq(rate, 1);

        output = -1E27 - 1; 
        rate = rateSetter.getBoundedRedemptionRate(output);
        assertEq(rate, 1);
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
        controller.toggleValidated();
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
        assertEq(now - rateSetter.lastUpdateTime() - rateSetter.updateRateDelay(), periodSize * 100000 + 1 - periodSize);
        assertTrue(now - rateSetter.lastUpdateTime() - rateSetter.updateRateDelay() > setterRelayer.maxRewardIncreaseDelay());
        assertEq(setterRelayer.getCallerReward(setterRelayer.lastUpdateTime(), setterRelayer.relayDelay()), maxUpdateCallerReward);

        rateSetter.updateRate(address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward + maxUpdateCallerReward);
    }
    function test_oracle_relayer_bounded_rate() public {
        oracleRelayer.modifyParameters("redemptionRateUpperBound", RAY + 1);
        oracleRelayer.modifyParameters("redemptionRateLowerBound", RAY - 1);

        rateSetter.updateRate(address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY + 1);

        controller.toggleValidated();

        hevm.warp(now + periodSize);
        rateSetter.updateRate(address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY - 1);
    }
}
