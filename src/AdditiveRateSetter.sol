pragma solidity 0.6.7;

contract AdditiveRateSetter {
    // redemptionPrice
    uint256  _par;
    // redemption rate
    uint256  _way;

    // market price
    uint256  public  fix;
    // component that is added/subtracted from the rate
    uint256  public  how;
    // last update time
    uint256  public  tau;

    uint256 constant RAY = 10 ** 27;

    // constructor
    constructor(uint par_) public {
        _par = fix = par_;
        _way = RAY;
        tau  = era();
    }

    function rdivide(uint x, uint y) public pure returns (uint z) {
        z = multiply(x, RAY) / y;
    }

    function rmultiply(uint x, uint y) public pure returns (uint z) {
        z = multiply(x, y) / RAY;
    }

    function multiply(uint x, uint y) public pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "uint-uint-mul-overflow");
    }

    function rpower(uint x, uint n, uint base) public pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, base)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }

    function era() public view returns (uint) {
        return block.timestamp;
    }

    // change the rate manually
    function mold(bytes32 param, uint val) public {
        if (param == 'way') _way = val;
    }

    // update the price, then return
    function par() public returns (uint) {
        prod();
        return _par;
    }
    // update the price, then return the rate
    function way() public returns (uint) {
        prod();
        return _way;
    }

    // market price
    function tell(uint256 ray) public {
        fix = ray;
    }
    // 'how' is the per second addition to the current rate
    function tune(uint256 ray) public {
        how = ray;
    }

    function prod() public {
        // get time since last update
        uint256 age = era() - tau;
        // if 0, return
        if (age == 0) return;  // optimised
        // set last update time to now
        tau = era();

        // if rate is not 0, update red price
        // the update is like the once from oracle relayer
        if (_way != RAY) _par = rmultiply(_par, rpower(_way, age, RAY));  // optimised

        // if we don't have anything to add/subtract from the rate, do nothing
        if (how == 0) return;  // optimised
        // total amount to add/subtract from the rate
        int128 wag = int128(how * age);
        // update the redemption rate
        // the update is done like: get the current delta between _way and RAY, add wag, then add the result to RAY
        _way = inj(prj(_way) + (fix < _par ? wag : -wag));
    }

    // returns the redemption rate given a deviation from a 0% rate (RAY)
    function inj(int128 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) + RAY
            : rdivide(RAY, RAY + uint256(-x));
    }
    // returns the delta between the current rate and RAY (0%)
    function prj(uint256 x) internal pure returns (int128) {
        return x >= RAY ? int128(x - RAY)
            : int128(RAY) - int128(rdivide(RAY, x));
    }
}
