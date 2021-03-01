// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC, Reflexer Labs, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.6.7;

import "geb-treasury-reimbursement/IncreasingTreasuryReimbursement.sol";

abstract contract OracleLike {
    function getResultWithValidity() virtual external view returns (uint256, bool);
}
abstract contract OracleRelayerLike {
    function redemptionPrice() virtual external returns (uint256);
    function redemptionRate() virtual public view returns (uint256);
}
abstract contract SetterRelayer {
    function relayRate(uint256) virtual external;
}
abstract contract DirectRateCalculator {
    function computeRate(uint256, uint256, uint256) virtual external returns (uint256);
}

contract DirectRateSetter is IncreasingTreasuryReimbursement {
    // --- Variables ---
    // Settlement flag
    uint256 public contractEnabled;                 // [0 or 1]
    // Last recorded system coin market price
    uint256 public latestMarketPrice;               // [ray]
    // When the price feed was last updated
    uint256 public lastUpdateTime;                  // [timestamp]
    // Enforced gap between calls
    uint256 public updateRateDelay;                 // [seconds]

    // --- System Dependencies ---
    // OSM or medianizer for the system coin
    OracleLike                public orcl;
    // OracleRelayer where the redemption price is stored
    OracleRelayerLike         public oracleRelayer;
    // The contract that will pass the new redemption rate to the oracle relayer
    SetterRelayer             public setterRelayer;
    // Calculator for the redemption rate
    DirectRateCalculator      public directRateCalculator;

    // --- Events ---
    event UpdateRedemptionRate(
        uint marketPrice,
        uint redemptionPrice,
        uint redemptionRate
    );
    event FailUpdateRedemptionRate(
        bytes reason
    );

    constructor(
      address oracleRelayer_,
      address setterRelayer_,
      address orcl_,
      address treasury_,
      address directRateCalculator_,
      uint256 baseUpdateCallerReward_,
      uint256 maxUpdateCallerReward_,
      uint256 perSecondCallerRewardIncrease_,
      uint256 updateRateDelay_
    ) public IncreasingTreasuryReimbursement(treasury_, baseUpdateCallerReward_, maxUpdateCallerReward_, perSecondCallerRewardIncrease_) {
        require(oracleRelayer_ != address(0), "DirectRateSetter/null-oracle-relayer");
        require(setterRelayer_ != address(0), "DirectRateSetter/null-setter-relayer");
        require(orcl_ != address(0), "DirectRateSetter/null-orcl");
        require(directRateCalculator_ != address(0), "DirectRateSetter/null-calculator");

        oracleRelayer        = OracleRelayerLike(oracleRelayer_);
        setterRelayer        = SetterRelayer(setterRelayer_);
        orcl                 = OracleLike(orcl_);
        directRateCalculator = DirectRateCalculator(directRateCalculator_);

        updateRateDelay    = updateRateDelay_;
        contractEnabled    = 1;

        emit ModifyParameters("orcl", orcl_);
        emit ModifyParameters("oracleRelayer", oracleRelayer_);
        emit ModifyParameters("setterRelayer", setterRelayer_);
        emit ModifyParameters("directRateCalculator", directRateCalculator_);
        emit ModifyParameters("updateRateDelay", updateRateDelay_);
    }

    /*
    * @notify Modify the address of a contract that the setter is connected to
    * @param parameter Contract name
    * @param addr The new contract address
    */
    function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
        require(contractEnabled == 1, "DirectRateSetter/contract-not-enabled");
        require(addr != address(0), "DirectRateSetter/null-addr");

        if (parameter == "orcl") orcl = OracleLike(addr);
        else if (parameter == "oracleRelayer") oracleRelayer = OracleRelayerLike(addr);
        else if (parameter == "setterRelayer") setterRelayer = SetterRelayer(addr);
        else if (parameter == "treasury") {
          require(StabilityFeeTreasuryLike(addr).systemCoin() != address(0), "DirectRateSetter/treasury-coin-not-set");
          treasury = StabilityFeeTreasuryLike(addr);
        }
        else if (parameter == "directRateCalculator") {
          directRateCalculator = DirectRateCalculator(addr);
        }
        else revert("DirectRateSetter/modify-unrecognized-param");
        emit ModifyParameters(
          parameter,
          addr
        );
    }
    /*
    * @notify Modify a uint256 parameter
    * @param parameter The parameter name
    * @param val The new parameter value
    */
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
        require(contractEnabled == 1, "DirectRateSetter/contract-not-enabled");
        if (parameter == "baseUpdateCallerReward") {
          require(val <= maxUpdateCallerReward, "DirectRateSetter/invalid-base-caller-reward");
          baseUpdateCallerReward = val;
        }
        else if (parameter == "maxUpdateCallerReward") {
          require(val >= baseUpdateCallerReward, "DirectRateSetter/invalid-max-caller-reward");
          maxUpdateCallerReward = val;
        }
        else if (parameter == "perSecondCallerRewardIncrease") {
          require(val >= RAY, "DirectRateSetter/invalid-caller-reward-increase");
          perSecondCallerRewardIncrease = val;
        }
        else if (parameter == "maxRewardIncreaseDelay") {
          require(val > 0, "DirectRateSetter/invalid-max-increase-delay");
          maxRewardIncreaseDelay = val;
        }
        else if (parameter == "updateRateDelay") {
          require(val >= 0, "DirectRateSetter/invalid-call-gap-length");
          updateRateDelay = val;
        }
        else revert("DirectRateSetter/modify-unrecognized-param");
        emit ModifyParameters(
          parameter,
          val
        );
    }
    /*
    * @notify Disable the rate setter
    */
    function disableContract() external isAuthorized {
        contractEnabled = 0;
    }

    // --- Feedback Mechanism ---
    /**
    * @notice Compute and set a new redemption rate
    * @param feeReceiver The proposed address that should receive the reward for calling this function
    *        (unless it's address(0) in which case msg.sender will get it)
    **/
    function updateRate(address feeReceiver) external {
        require(contractEnabled == 1, "DirectRateSetter/contract-not-enabled");
        // Check delay between calls
        require(either(subtract(now, lastUpdateTime) >= updateRateDelay, lastUpdateTime == 0), "DirectRateSetter/wait-more");
        // Get price feed updates
        (uint256 marketPrice, bool hasValidValue) = orcl.getResultWithValidity();
        // If the oracle has a value
        require(hasValidValue, "DirectRateSetter/invalid-oracle-value");
        // If the price is non-zero
        require(marketPrice > 0, "DirectRateSetter/null-price");
        // Get the latest redemption price
        uint redemptionPrice = oracleRelayer.redemptionPrice();
        // Get the caller's reward
        uint256 callerReward = getCallerReward(lastUpdateTime, updateRateDelay);
        // Store the latest market price
        latestMarketPrice = ray(marketPrice);
        // Calculate the new rate
        uint256 calculated = directRateCalculator.computeRate(
            marketPrice,
            redemptionPrice,
            oracleRelayer.redemptionRate()
        );
        // Store the timestamp of the update
        lastUpdateTime = now;
        // Update the rate using the setter relayer
        try setterRelayer.relayRate(calculated) {
          // Emit success event
          emit UpdateRedemptionRate(
            ray(marketPrice),
            redemptionPrice,
            calculated
          );
        }
        catch(bytes memory revertReason) {
          emit FailUpdateRedemptionRate(
            revertReason
          );
        }
        // Pay the caller for updating the rate
        rewardCaller(feeReceiver, callerReward);
    }

    // --- Getters ---
    /**
    * @notice Get the market price from the system coin oracle
    **/
    function getMarketPrice() external view returns (uint256) {
        (uint256 marketPrice, ) = orcl.getResultWithValidity();
        return marketPrice;
    }
    /**
    * @notice Get the redemption and the market prices for the system coin
    **/
    function getRedemptionAndMarketPrices() external returns (uint256 marketPrice, uint256 redemptionPrice) {
        (marketPrice, ) = orcl.getResultWithValidity();
        redemptionPrice = oracleRelayer.redemptionPrice();
    }
}
