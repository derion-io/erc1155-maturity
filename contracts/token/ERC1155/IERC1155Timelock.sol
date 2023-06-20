// SPDX-License-Identifier: MIT
// Derivable Contracts (last updated v4.7.0) (token/ERC1155/IERC1155Timelock.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IERC1155Timelock is IERC1155 {
    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function locktimeOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {locktimeOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function locktimeOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
}
