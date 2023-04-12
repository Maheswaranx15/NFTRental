//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/ITransferProxy.sol";

contract TransferProxy is AccessControl, ITransferProxy {
    event operatorChanged(address indexed from, address indexed to);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    address public owner;
    address public operator;
    address public escrowWallet;

    constructor() {
        owner = msg.sender;
        _setupRole("ADMIN_ROLE", msg.sender);
        _setupRole("OPERATOR_ROLE", operator);
    }

    function changeOperator(address _operator)
        external
        onlyRole("ADMIN_ROLE")
        returns (bool)
    {
        require(
            _operator != address(0),
            "Operator: new operator is the zero address"
        );
        _revokeRole("OPERATOR_ROLE", operator);
        operator = _operator;
        _setupRole("OPERATOR_ROLE", operator);
        emit operatorChanged(address(0), operator);
        return true;
    }

    function changeEscrowWalletAddress(address _escrow)
        external
        onlyRole("ADMIN_ROLE")
        returns (bool)
    {
        require(
            _escrow != address(0),
            "Operator: new operator is the zero address"
        );
        _revokeRole("OPERATOR_ROLE", escrowWallet);
        emit operatorChanged(escrowWallet, _escrow);
        escrowWallet = _escrow;
        _setupRole("OPERATOR_ROLE", escrowWallet);
        return true;
    }

    /** change the Ownership from current owner to newOwner address
        @param newOwner : newOwner address */

    function transferOwnership(address newOwner)
        external
        onlyRole("ADMIN_ROLE")
        returns (bool)
    {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _revokeRole("ADMIN_ROLE", owner);
        owner = newOwner;
        _setupRole("ADMIN_ROLE", newOwner);
        emit OwnershipTransferred(owner, newOwner);
        return true;
    }

    function erc721safeTransferFrom(
        IERC721 token,
        address from,
        address to,
        uint256 tokenId
    ) external override onlyRole("OPERATOR_ROLE") {
        token.safeTransferFrom(from, to, tokenId);
    }

    function erc1155safeTransferFrom(
        IERC1155 token,
        address from,
        address to,
        uint256 tokenId,
        uint256 value,
        bytes calldata data
    ) external override onlyRole("OPERATOR_ROLE") {
        token.safeTransferFrom(from, to, tokenId, value, data);
    }

    function erc20safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) external override onlyRole("OPERATOR_ROLE") {
        require(
            token.transferFrom(from, to, value),
            "failure while transferring"
        );
    }
}