# Fuzzing the Rate Setter

The contracts in this folder are the fuzz scripts for the rate setter.

## Setup

To run the fuzzer, set up echidna (https://github.com/crytic/echidna) in your machine

Then run

```
echidna-test src/test/fuzz/RateSetterFuzz.sol --contract RateSetterFuzz  --config echidna.yaml
```

- PIRawPerSecondCalculatorFuzz: Unit fuzz of the PIRawPerSecondCalculator, turning function scrambleParams to public will make the script also fuzz the calculator params.
- PIScaledPerSecondCalculatorFuzz: Unit fuzz of the PIScaledPerSecondCalculator, scrambleParams also present.

Configs are in the root of this repo (echidna.yaml). Settings for number of runs should be high due to the need to test larger timeframes (echidna will space txs by very little initially, and then will increase the lapse over time.)

# RateSetter

## Long delays between updates

Fuzzing the rate setter under normal situations. Both the market price and redemption prices are set by the fuzzer, then updateRate is called. Uses modified math libraries to force fail on over/underflows.

Result (200000 runs):
Analyzing contract: /Users/fabio/Documents/reflexer/geb-rrfm-rate-setter/src/test/fuzz/RateSetterFuzz.sol:RateSetterFuzz
assertion in updateRate: passed! 🎉

Unique instructions: 1848
Unique codehashes: 6
Seed: 5106227317005529644

## Testing RateSetterMath function bounds

Run echidna against RateSetterMathFuzz contract in RateSetterFuzz.sol. It will list the boundaries (reduced to the approximate lowest values) in which each of the functions fail.

Tests found: 20  
Seed: -7365341584816032386  
Unique instructions: 1702  
Unique codehashes: 1  
  
assertion in rmultiply: FAILED!

Call sequence:  
1.rmultiply(7809,15024098366702346957317720552913108272168534286289751166913128453327653363)
  
assertion in ray: FAILED!

Call sequence:  
1.ray(115805142323603873391887599927307795734734227558342184682008398989764)

assertion in multiply: FAILED!

Call sequence:  
1.multiply(5628561547966042697103162239039125431,21035297369228784755336960438572312443892)

assertion in multiply: FAILED!

Call sequence:  
1.multiply(47861427672936928593953784630510805528623173677312808027781882,1232353589782595)

assertion in wmultiply: FAILED!

Call sequence:  
1.wmultiply(12441034916255294240857114749882360,9309652966274327860591761690485199158240150)

assertion in subtract: FAILED!

Call sequence:  
1.subtract(0,1)

assertion in rad: FAILED!

Call sequence:  
1.rad(116013296320436057781065573935651418788226181515370)

assertion in rmultiply: FAILED!  
  
Call sequence:  
1.rmultiply(7447960859926524547645999844367662973658665821786126442411202602445,7809445377)

assertion in addition: PASSED!

assertion in RAY: PASSED!

assertion in WAD: PASSED!

assertion in rdivide: FAILED!  
  
Call sequence:  
1.rdivide(115815259545614009752261420574350356067590887895382,47796862585506010573277956326249697490483937192728225)

assertion in wmultiply: FAILED!

Call sequence:  
1.wmultiply(-4811421145914031410106876136193192816,12437255051748474035932179362274999194864)

assertion in subtract: PASSED!

assertion in addition: PASSED!

assertion in rpower: FAILED!  
  
Call sequence:  
1.rpower(341161058004255232789887354714630258445,19182360968612251051110363757612368,0)

assertion in minimum: PASSED!

assertion in addition: FAILED!

Call sequence:  
1.addition(0,-1)

assertion in wdivide: FAILED!  
  
Call sequence:  
1.wdivide(116000590732825764887816964812124964183176088392092330089028,1062063365111883209652626565867040697822683834│

assertion in multiply: FAILED!

Call sequence:  
1.multiply(-21954613017423466056632156732371920610,2681830920661240133031828806302824475383)
