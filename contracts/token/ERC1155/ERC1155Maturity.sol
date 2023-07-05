// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC1155/ERC1155.sol)
// Derivable Contracts (ERC1155Maturity)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

import "./IERC1155Maturity.sol";
import "./libs/TimeBalance.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Maturity is IERC1155Maturity, IERC1155MetadataURI {
    using TimeBalance for uint;

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => mapping(address => uint256)) internal s_timeBalances;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "ERC1155: setting approval status for self");
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from ==  msg.sender || isApprovedForAll[from][ msg.sender],
            "ERC1155: caller is not token owner or approved"
        );

        _safeTransferFrom(from, to, id, amount, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        uint256 fromBalance = s_timeBalances[id][from];
        uint timelockAmount;
        (s_timeBalances[id][from], timelockAmount) = fromBalance.split(amount);
        s_timeBalances[id][to] = s_timeBalances[id][to].merge(timelockAmount);

        emit TransferSingle( msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck( msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == msg.sender || isApprovedForAll[from][msg.sender],
            "ERC1155: caller is not token owner or approved"
        );
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        for (uint256 i = 0; i < ids.length;) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint timelockAmount;
            (s_timeBalances[id][from], timelockAmount) = s_timeBalances[id][from].split(amount);
            s_timeBalances[id][to] = s_timeBalances[id][to].merge(timelockAmount);
        
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return s_timeBalances[id][account].amount();
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /*//////////////////////////////////////////////////////////////
                              MATURITY LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function maturityOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return s_timeBalances[id][account].locktime();
    }

    /**
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function maturityOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchLocktimes = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchLocktimes[i] = maturityOf(accounts[i], ids[i]);
        }

        return batchLocktimes;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id, uint256 amount, uint256 locktime, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        uint timelockAmount = TimeBalance.pack(amount, locktime);
        s_timeBalances[id][to] = s_timeBalances[id][to].merge(timelockAmount);

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, data);
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256 locktime,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length;
        require(to != address(0), "ERC1155: mint to the zero address");
        require(idsLength == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < idsLength;) {
            uint timelockAmount = TimeBalance.pack(amounts[i], locktime);
            s_timeBalances[ids[i]][to] = s_timeBalances[ids[i]][to].merge(timelockAmount);
        
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, address(0), to, ids, amounts, data);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        (s_timeBalances[id][from],) = s_timeBalances[id][from].split(amount);

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            (s_timeBalances[id][from], ) = s_timeBalances[id][from].split(amounts[i]);
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }
}
