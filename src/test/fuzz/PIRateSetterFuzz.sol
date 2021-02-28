pragma solidity ^0.6.7;

import {MockToken} from '../../mock/MockToken.sol';
import {MockPIDCalculator} from '../../mock/MockPIDCalculator.sol';
import {FuzzablePIRawPerSecondCalculator} from './FuzzablePIRawPerSecondCalculator.sol';
import {FuzzablePIRateSetter} from "./FuzzablePIRateSetter.sol";
import "../../mock/MockOracleRelayer.sol";
import "../../mock/MockTreasury.sol";
import "geb-treasury-reimbursement/math/GebMath.sol";

abstract contract Hevm {
    function warp(uint) virtual public;
    function roll(uint) virtual public;
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

contract PIRateSetterFuzz {
    MockToken systemCoin;
    MockTreasury treasury;
    MockOracleRelayer oracleRelayer;
    FuzzablePIRateSetter rateSetter;

    FuzzablePIRawPerSecondCalculator calculator;
    Feed orcl;

    uint256 periodSize = 3600;
    uint256 baseUpdateCallerReward = 5E18;
    uint256 maxUpdateCallerReward  = 10E18;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% per hour

    uint256 coinsToMint = 1E40;

    uint RAY = 10 ** 27;
    uint WAD = 10 ** 18;

    uint256 internal constant NEGATIVE_RATE_LIMIT         = TWENTY_SEVEN_DECIMAL_NUMBER - 1;
    uint256 internal constant TWENTY_SEVEN_DECIMAL_NUMBER = 10 ** 27;
    uint256 internal constant EIGHTEEN_DECIMAL_NUMBER     = 10 ** 18;

    constructor() public {

        systemCoin = new MockToken(coinsToMint);

        oracleRelayer = new MockOracleRelayer();
        orcl = new Feed(1 ether, true);
        treasury = new MockTreasury(address(systemCoin));

        systemCoin.transfer(address(treasury), coinsToMint);

        // calculator = new MockPIDCalculator();
        calculator = new FuzzablePIRawPerSecondCalculator(
            int(EIGHTEEN_DECIMAL_NUMBER),
            int(EIGHTEEN_DECIMAL_NUMBER),
            999997208243937652252849536, // 1% per hour
            3600,
            EIGHTEEN_DECIMAL_NUMBER,
            TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER,
            -int(NEGATIVE_RATE_LIMIT),
            new int[](5)
        );
        rateSetter = new FuzzablePIRateSetter(
          address(oracleRelayer),
          address(orcl),
          address(treasury),
          address(calculator),
          baseUpdateCallerReward,
          maxUpdateCallerReward,
          perSecondCallerRewardIncrease,
          periodSize
        );

        treasury.setTotalAllowance(address(rateSetter), uint(-1));
        treasury.setPerBlockAllowance(address(rateSetter), 5E45);
    }

    // run with the assert math library
    function updateRate(uint price, uint price2) public {
            changeMarketPrice(price);
            changeRedemptionPrice(price2);
            rateSetter.updateRate(address(0));
    }

    // aux functions to fuzz the params
    function changeRedemptionPrice(uint value) internal {
        oracleRelayer.modifyParameters("redemptionPrice", value);
    }

    function changeMarketPrice(uint price) internal {
        orcl.updateTokenPrice(price);
    }
}

contract GebMathFuzz is GebMath {

}
