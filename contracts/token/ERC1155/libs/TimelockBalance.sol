// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./SimpleMath.sol";

library TimelockBalance {
    uint constant MAX_TIME = uint(type(uint32).max) << 224;
    uint constant MAX_BALANCE = type(uint224).max;

    function pack(uint b, uint t) internal pure returns (uint) {
        require(t <= MAX_TIME, "Timelock: t overflow");
        require(b <= MAX_BALANCE, "Timelock: b overflow");
        return (t << 224) | b;
    }

    function amount(uint x) internal pure returns (uint) {
        unchecked {
            return x & MAX_BALANCE;
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
            require(yt <= xt, "Timelock: locktime order");
            uint yb = y & MAX_BALANCE;
            uint xb = x & MAX_BALANCE;
            uint zb = xb + yb;
            require(zb <= MAX_BALANCE, "Timelock: zb overflow");
            return x + yb;
        }
    }

    function split(uint z, uint yb) internal pure returns (uint x, uint y) {
        unchecked {
            uint zb = z & MAX_BALANCE;
            if (zb == yb) {
                return (0, z); // full transfer
            }
            require(zb > yb, "Timelock: insufficient balance");
            x = z - yb; // preserve the locktime
            y = (z & MAX_TIME) | yb;
        }
    }
}
