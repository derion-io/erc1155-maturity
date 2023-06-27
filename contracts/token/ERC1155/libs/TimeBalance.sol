// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./SimpleMath.sol";

library TimeBalance {
    uint constant TIME_MAX = type(uint32).max;
    uint constant TIME_MASK = TIME_MAX << 224;
    uint constant BALANCE_MAX = type(uint224).max;
    uint constant BALANCE_MASK = BALANCE_MAX;

    function pack(uint b, uint t) internal pure returns (uint) {
        require(t <= type(uint32).max, "Maturity: t overflow");
        require(b <= BALANCE_MAX, "Maturity: b overflow");
        return (t << 224) | b;
    }

    function amount(uint x) internal pure returns (uint) {
        unchecked {
            return x & BALANCE_MASK;
        }
    }

    function locktime(uint x) internal pure returns (uint) {
        unchecked {
            return x >> 224;
        }
    }

    function merge(uint x, uint y) internal view returns (uint z) {
        unchecked {
            if (x == 0) {
                return y;
            }
            uint xt = SimpleMath.max(block.timestamp, x >> 224);
            uint yt = y >> 224;
            require(yt <= xt, "Maturity: locktime order");
            uint yb = y & BALANCE_MASK;
            uint xb = x & BALANCE_MASK;
            uint zb = xb + yb;
            require(zb <= BALANCE_MAX, "Maturity: zb overflow");
            return x + yb;
        }
    }

    function split(uint z, uint yb) internal pure returns (uint x, uint y) {
        unchecked {
            uint zb = z & BALANCE_MASK;
            if (zb == yb) {
                return (0, z); // full transfer
            }
            require(zb > yb, "Maturity: insufficient balance");
            x = z - yb; // preserve the locktime
            y = (z & TIME_MASK) | yb;
        }
    }
}
