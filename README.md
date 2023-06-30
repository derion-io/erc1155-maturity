# ERC-1155 Maturity

ERC-1155 Maturity is an implementation of [ERC-1155](https://eips.ethereum.org/EIPS/eip-1155) that reduces the token balance size to `uint192` (from `uint256`) and adds an `uint32` maturity time.

The maturity feature creates a soft-lock effect for newly minted token balances. Once the maturity time has elapsed, the position becomes matured and fully fungible. However, until that time, the balance is only partly fungible and subject to the following rules:

* A zero balance is a fully matured balance.
* A balance with a maturity time equal to or older than `block.timestamp` is a fully matured balance.
* A maturing position can be divided into smaller balances with the same maturity time.
* A maturing position cannot be transferred or merged into a more mature position.
* Merging two positions will result in a position with a later maturity time.

The maturity time can be queried using the `IERC1155Maturity` interface:

```solidity
interface IERC1155Maturity is IERC1155 {
    /**
     * @dev Returns the maturity time of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function maturityOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {maturityOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function maturityOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
}
```