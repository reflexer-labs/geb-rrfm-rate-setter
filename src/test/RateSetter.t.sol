pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {MockPIDValidator} from '../mock/MockPIDValidator.sol';
import {RateSetter} from "../RateSetter.sol";
import "../mock/MockOracleRelayer.sol";
import "../mock/MockTreasury.sol";

abstract contract DSValueLike {
    function getResultWithValidity() virtual external view returns (uint256, bool);
}
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
contract OSM {
    address public priceSource;
    uint16  constant ONE_HOUR = uint16(3600);
    uint16  public updateDelay = ONE_HOUR;
    uint64  public lastUpdateTime;

    struct Feed {
        uint128 value;
        uint128 isValid;
    }

    Feed currentFeed;
    Feed nextFeed;

    constructor (address priceSource_) public {
        priceSource = priceSource_;
        if (priceSource != address(0)) {
          (uint256 priceFeedValue, bool hasValidValue) = getPriceSourceUpdate();
          if (hasValidValue) {
            nextFeed = Feed(uint128(uint(priceFeedValue)), 1);
            currentFeed = nextFeed;
            lastUpdateTime = latestUpdateTime(currentTime());
          }
        }
    }

    // --- Math ---
    function add(uint64 x, uint64 y) internal pure returns (uint64 z) {
        z = x + y;
        require(z >= x);
    }

    function currentTime() internal view returns (uint) {
        return block.timestamp;
    }

    function latestUpdateTime(uint timestamp) internal view returns (uint64) {
        require(updateDelay != 0, "OSM/update-delay-is-zero");
        return uint64(timestamp - (timestamp % updateDelay));
    }

    function passedDelay() public view returns (bool ok) {
        return currentTime() >= add(lastUpdateTime, updateDelay);
    }

    function getPriceSourceUpdate() internal view returns (uint256, bool) {
        try DSValueLike(priceSource).getResultWithValidity() returns (uint256 priceFeedValue, bool hasValidValue) {
          return (priceFeedValue, hasValidValue);
        }
        catch(bytes memory) {
          return (0, false);
        }
    }

    function updateResult() external {
        require(passedDelay(), "OSM/not-passed");
        (uint256 priceFeedValue, bool hasValidValue) = getPriceSourceUpdate();
        if (hasValidValue) {
            currentFeed = nextFeed;
            nextFeed = Feed(uint128(uint(priceFeedValue)), 1);
            lastUpdateTime = latestUpdateTime(currentTime());
        }
    }

    function getResultWithValidity() external view returns (uint256,bool) {
        return (uint(currentFeed.value), currentFeed.isValid == 1);
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

    MockPIDValidator validator;
    Feed orcl;
    OSM osm;

    uint256 periodSize = 3600;
    uint256 baseUpdateCallerReward = 5E18;
    uint256 maxUpdateCallerReward  = 10E18;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% per hour

    uint256 coinsToMint = 1E40;

    uint RAY = 10 ** 27;
    uint WAD = 10 ** 18;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        systemCoin = new DSToken("RAI");

        oracleRelayer = new MockOracleRelayer();
        orcl = new Feed(1 ether, true);
        osm = new OSM(address(orcl));
        treasury = new MockTreasury(address(systemCoin));

        systemCoin.mint(address(treasury), coinsToMint);

        validator = new MockPIDValidator();
        rateSetter = new RateSetter(
          address(oracleRelayer),
          address(osm),
          address(treasury),
          address(validator),
          baseUpdateCallerReward,
          maxUpdateCallerReward,
          perSecondCallerRewardIncrease,
          periodSize
        );

        treasury.setTotalAllowance(address(rateSetter), uint(-1));
        treasury.setPerBlockAllowance(address(rateSetter), 5E45);
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
        rateSetter.modifyParameters("pidValidator", address(0x12));

        rateSetter.modifyParameters("baseUpdateCallerReward", 1);
        rateSetter.modifyParameters("maxUpdateCallerReward", 2);
        rateSetter.modifyParameters("perSecondCallerRewardIncrease", RAY);
        rateSetter.modifyParameters("updateRateDelay", 1);

        // Check
        assertTrue(address(rateSetter.orcl()) == address(0x12));
        assertTrue(address(rateSetter.oracleRelayer()) == address(0x12));
        assertTrue(address(rateSetter.treasury()) == address(newTreasury));
        assertTrue(address(rateSetter.pidValidator()) == address(0x12));

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
        rateSetter.updateRate(RAY + 1, address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);
    }
    function test_first_update_rate_with_warp() public {
        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY + 1, address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);
    }
    function testFail_update_before_period_passed() public {
        rateSetter.updateRate(RAY + 1, address(0x123));
        rateSetter.updateRate(RAY + 1, address(0x123));
    }
    function test_two_updates() public {
        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY + 1, address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);

        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY + 2, address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward * 2);
        assertEq(oracleRelayer.redemptionRate(), RAY + 2);
    }
    function test_null_rate_needed_submit_different() public {
        validator.toggleValidated();
        rateSetter.updateRate(RAY - 1, address(0x123));
        assertEq(systemCoin.balanceOf(address(0x123)), baseUpdateCallerReward);
        assertEq(oracleRelayer.redemptionRate(), RAY - 2);

        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY + 2, address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY - 2);
    }
    function test_oracle_relayer_bounded_rate() public {
        oracleRelayer.modifyParameters("redemptionRateUpperBound", RAY + 1);
        oracleRelayer.modifyParameters("redemptionRateLowerBound", RAY - 1);

        rateSetter.updateRate(RAY + 2, address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY + 1);

        validator.toggleValidated();

        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY - 2, address(0x123));
        assertEq(oracleRelayer.redemptionRate(), RAY - 1);
    }
    function test_update_oracle() public {
        orcl.updateTokenPrice(1.05E18);

        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY + 1, address(0x123));

        (uint newOsmPrice, bool validity) = osm.getResultWithValidity();
        assertEq(newOsmPrice, 1E18);
        assertTrue(validity);

        hevm.warp(now + periodSize);
        rateSetter.updateRate(RAY + 1, address(0x123));

        (newOsmPrice, validity) = osm.getResultWithValidity();
        assertEq(newOsmPrice, 1.05E18);
        assertTrue(validity);
    }
}
