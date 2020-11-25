# Fuzzing the Rate Setter

The contracts in this folder are the fuzz scripts for the Rate calculators.

To run the fuzzer, set up echidna (https://github.com/crytic/echidna) in your machine

Then run 
```
echidna-test src/test/fuzz/RateSetterFuzz.sol --contract RateSetterFuzz  --config echidna.yaml
```

- PIRawPerSecondCalculatorFuzz: Unit fuzz of the PIRawPerSecondCalculator, turning function scrambleParams to public will make the script also fuzz the calculator params.
- PIScaledPerSecondCalculatorFuzz: Unit fuzz of the PIScaledPerSecondCalculator, scrambleParams also present.

Configs are in the root of this repo (echidna.yaml). Settings for number of runs should be high due to the need to test larger timeframes (echidna will space txs by very little initially, and then will increase the lapse over time.)

# RateSetter

## Invariants mapped
# Too long between updates
Fuzzing ratesetter under normal situations. Both market price and redemption prices are set by the fuzzer, then updateRate is called. Use modified Math libraries to force fail on over/underflows.

Result (200000 runs):
Analyzing contract: /Users/fabio/Documents/reflexer/geb-rrfm-rate-setter/src/test/fuzz/RateSetterFuzz.sol:RateSetterFuzz
assertion in updateRate: passed! 🎉

Unique instructions: 1848
Unique codehashes: 6
Seed: 5106227317005529644


