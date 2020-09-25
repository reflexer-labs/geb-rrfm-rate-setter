pragma solidity 0.6.7;

contract MockPIDValidator {
  uint constant RAY = 10**27;

  uint256 internal validated = RAY + 2;

  function toggleValidated() public {
      if (validated == 0) {
        validated = RAY + 2;
      } else {
        validated = RAY - 2;
      }
  }
  function validateSeed(uint256, uint256, uint256, uint256, uint256, uint256) virtual external returns (uint256) {
      return validated;
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
  function uprad() virtual external view returns (uint256) {
      return RAY;
  }
  function adi() virtual external view returns (uint256) {
      return RAY;
  }
  function adat() virtual external view returns (uint256) {
      return 0;
  }
}
