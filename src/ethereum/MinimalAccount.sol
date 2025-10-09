// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// IAccount is the core interface that defines the contract requirement for an account abstraction
// Any contract that wants to act as an account abstraction wallet must implement this interface
import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";

// PackedUserOperation is a data structure that represents a user operation in the ERC-4337 account abstraction
// Like a package delivery request in a logistics system
// the sender address, recipient address, package content, tracking number, signature, fee
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalAccount is IAccount, Ownable {
    constructor(address entrypoint) Ownable(msg.sender) {
    }

    ////////////////////////////////////////////////////////////////////////
    // Internal Functions //////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) 
        internal
        view 
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success); 
        }
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) 
        external
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        // _validateNonce()
        _payPrefund(missingAccountFunds);
    }
}