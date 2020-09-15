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
  function validateSeed(uint256, uint256, uint256, uint256, uint256) virtual external returns (uint8) {
      return validationResult;
  }
  function rt(uint256, uint256, uint256) virtual external view returns (uint256) {
      return 31536000;
  }
  function pscl() virtual external view returns (uint256) {
      return RAY;
  }
  function tlv() virtual external view returns (uint256) {
      return 1;
  }
  function lprad() virtual external view returns (uint256) {
      return RAY;
  }
  function adi() virtual external view returns (uint256) {
      return RAY;
  }
}
