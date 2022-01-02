# Redemption Rate Feedback Mechanism Rate Setter

RRFM rate setters are contracts meant to call the PI/D calculators, fetch the latest computed redemption rate and then set that new rate in a GEB oracle relayer.

There are two rate setters in this repo:

- **DirectRateSetter**: this rate setter is meant to call a [DirectRateCalculator](https://github.com/reflexer-labs/geb-rrfm-calculators/blob/master/src/calculator/DirectRateCalculator.sol) and pass its result to the [SetterRelayer](https://github.com/reflexer-labs/geb-rrfm-rate-setter/blob/master/src/SetterRelayer.sol)
- **PIRateSetter**; this rate setter is meant to call any P or PI rate setter from [this repository](https://github.com/reflexer-labs/geb-rrfm-calculators/tree/master/src/calculator) and pass its result to the [SetterRelayer](https://github.com/reflexer-labs/geb-rrfm-rate-setter/blob/master/src/SetterRelayer.sol)

## Bug Bounty

There's an [ongoing bug bounty program](https://immunefi.com/bounty/reflexer/) covering contracts from this repo.
