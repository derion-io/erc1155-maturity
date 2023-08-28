// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

library TimeBalance {
    uint256 constant TIME_MAX = type(uint32).max;
    uint256 constant TIME_MASK = TIME_MAX << 224;
    uint256 constant BALANCE_MAX = type(uint224).max;
    uint256 constant BALANCE_MASK = BALANCE_MAX;

    function merge(uint256 x, uint256 y) internal view returns (uint256 z) {
        unchecked {
            if (x == 0) {
                return y;
            }
            uint256 xt = Math.max(block.timestamp, x >> 224);
            uint256 yt = y >> 224;
            require(yt <= xt, "Maturity: locktime order");
            uint256 yb = y & BALANCE_MASK;
            uint256 xb = x & BALANCE_MASK;
            uint256 zb = xb + yb;
            require(zb <= BALANCE_MAX, "Maturity: zb overflow");
            return x + yb;
        }
    }

    function pack(uint256 b, uint256 t) internal pure returns (uint256) {
        require(t <= type(uint32).max, "Maturity: t overflow");
        require(b <= BALANCE_MAX, "Maturity: b overflow");
        return (t << 224) | b;
    }

    function amount(uint256 x) internal pure returns (uint256) {
        return x & BALANCE_MASK;
    }

    function locktime(uint256 x) internal pure returns (uint256) {
        return x >> 224;
    }

    function split(uint256 z, uint256 yb) internal pure returns (uint256 x, uint256 y) {
        unchecked {
            uint256 zb = z & BALANCE_MASK;
            if (zb == yb) {
                return (0, z); // full transfer
            }
            require(zb > yb, "Maturity: insufficient balance");
            x = z - yb; // preserve the locktime
            y = (z & TIME_MASK) | yb;
        }
    }
}
