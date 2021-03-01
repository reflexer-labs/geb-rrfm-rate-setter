pragma solidity 0.6.7;

contract MockDirectRateCalculator {
    uint256 redemptionRate;

    function setRate(uint256 redemptionRate_) public {
        redemptionRate = redemptionRate_;
    }

    function computeRate(uint256 marketPrice, uint256 redemptionPrice, uint256 rate) external returns (uint256) {
        return redemptionRate;
    }
}
