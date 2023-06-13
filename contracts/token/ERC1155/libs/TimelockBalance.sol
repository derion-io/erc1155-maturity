// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./SimpleMath.sol";

library TimelockBalance {
    function pack(uint a, uint t) internal pure returns (uint) {
        require(t <= type(uint32).max, "Timelock: uint32 overflow");
        require(a <= type(uint224).max, "Timelock: uint224 overflow");
        return a | (t << 224);
    }

    function amount(uint x) internal pure returns (uint) {
        unchecked {
            return x & type(uint224).max;
        }
    }

    function locktime(uint x) internal pure returns (uint) {
        unchecked {
            return x >> 224;
        }
    }

    function add(uint x, uint y) internal view returns (uint z) {
        unchecked {
            uint yb = y & type(uint224).max;
            uint yt = y >> 224;
            if (yt == 0) {
                yt = block.timestamp;
            }
            if (x == 0) {
                return (yt << 224) | yb;
            }
            uint xb = x & type(uint224).max;
            uint zb = xb + yb;
            require(zb <= type(uint224).max, "Timelock: uint224 overflow");
            uint xt = x >> 224;
            if (xt == 0) {
                xt = block.timestamp;
            }
            if (xt != yt) {
                z = SimpleMath.avgRoundingUp(xt*xb, yt*yb, zb) << 224;
            } else {
                z = xt << 224;
            }
            z |= zb;
        }
    }

    function sub(uint x, uint y) internal view returns (uint) {
        unchecked {
            require(x >> 224 <= block.timestamp, "Timelock: unexpired");
            uint xb = x & type(uint224).max;
            if (xb == y) {
                return 0;
            }
            require(xb > y, "Timelock: insufficient balance for transfer");
            return x - y; // preserve the time
        }
    }
}
