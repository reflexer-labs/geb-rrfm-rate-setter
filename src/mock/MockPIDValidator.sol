pragma solidity 0.6.7;

contract MockPIDValidator {
  uint constant RAY = 10**27;

  uint8 internal validationResult = 1;

  function toggleValidationResult() public {
      if (validationResult == 0) {
        validationResult = 1;
      } else {
        validationResult = 0;
      }
  }
  function scan(uint256, uint256, uint256, uint256, uint256) virtual external returns (uint8) {
      return validationResult;
  }
  function clock(uint256, uint256, uint256) virtual external view returns (uint256) {
      return 31536000;
  }
  function nick() virtual external view returns (uint256) {
      return RAY;
  }
  function blob() virtual external view returns (uint256) {
      return 1;
  }
  function goof() virtual external view returns (uint256) {
      return RAY;
  }
  function wax() virtual external view returns (uint256) {
      return RAY;
  }
}
