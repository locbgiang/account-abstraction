// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// IAccount is the core interface that defines the contract requirement for an account abstraction
// Any contract that wants to act as an account abstraction wallet must implement this interface
import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";

// PackedUserOperation is a data structure that represents a user operation in the ERC-4337 account abstraction
// Like a package delivery request in a logistics system
// the sender address, recipient address, package content, tracking number, signature, fee
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

// Ownable is a contract from OpenZeppelin
// Single Owner: Only one address can be the owner at a time
// Owner Transfer: The owner can transfer ownership to another address
// Access control: Provides the onlyOwner modifier to restrict function access
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

    /**
     * This is a core part of the ERC-4337 account abstraction standard
     * Called by EntryPoint contract to validate a user operation before executing it.
     * It acts as a security checkpoint to ensure the operation is legitimate and properly funded.
     * @param userOp the packed user operation containing all the transaction details
     * @param userOpHash a hash of the user operation used for signature verification
     * @param missingAccountFunds the amount of ETH needed to cover gas fees that the account doesnt currently have
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) 
        external
        returns (uint256 validationData)
    {
        // signature validation:
        // Calls the internal _validateSignature function to verify that the operation was signed
        // Returns the validation data that indicates whether the signature is valid
        validationData = _validateSignature(userOp, userOpHash);
        // _validateNonce()
        _payPrefund(missingAccountFunds);
    }
}