pragma solidity 0.6.7;

contract MockPIController {
  uint constant RAY = 10**27;

  int256 internal validated = 2;

  function toggleValidated() public {
      if (validated == 0) {
        validated = 2;
      } else {
        validated = -2;
      }
  }
  function update(int256) virtual external returns (int256, int256, int256) {
      return (int(validated), 0, 0);
  }
  function perSecondIntegralLeak() virtual external view returns (uint256) {
      return RAY;
  }
  function elapsed() virtual external view returns (uint256) {
      return 1;
  }
}
