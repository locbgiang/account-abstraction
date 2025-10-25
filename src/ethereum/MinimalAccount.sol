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

// EntryPoint is a singleton contract that acts as the central coordinator for all ERC-4337 
// Think of it as the 'traffic controller' for all smart contract wallets
// Key Responsibilities of EntryPoint:
// Operation Validation, gas management, execution, bundling, security
import {IEntryPoint} from '@account-abstraction/contracts/interfaces/IEntryPoint.sol';


/**
 * @title MinimalAccount
 * @author Loc
 * @notice The flow:
 * 1. User submits a PackedUserOperation to a bundle
 * 2. Bundler calls EntryPoint.handleOps() with the operation
 * 3. EntryPoint calls this.validateUserOp() to verify the operation
 * 4. This contract validates signature and pay gas fee
 * 5. EntryPoint executes the actual transaction if validation passes
 */
contract MinimalAccount is IAccount, Ownable {

    ////////////////////////////////////////////////
    // Errors //////////////////////////////////////
    ////////////////////////////////////////////////
    
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    ///////////////////////////////////////////////////////////////
    // State Variables ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////

    IEntryPoint private immutable i_entryPoint;

    ///////////////////////////////////////////////////////////////////////////
    // Modifiers //////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    ////////////////////////////////////////////////////////////
    // Functions ///////////////////////////////////////////////
    ////////////////////////////////////////////////////////////

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    /////////////////////////////////////////////////////////////////////
    // External Function ////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    function execute(
        address dest, 
        uint256 value, 
        bytes calldata functionData
    ) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

     /**
     * This is a core part of the ERC-4337 account abstraction standard.
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
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        // signature validation:
        // Calls the internal _validateSignature function to verify that the operation was signed
        // Returns the validation data that indicates whether the signature is valid
        validationData = _validateSignature(userOp, userOpHash);
        // _validateNonce()

        // pay any missing funds to the EntryPoint to cover gas costs
        // if the account doesn't have enough ETH for gas, this transfer the required amount
        _payPrefund(missingAccountFunds);
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

    /////////////////////////////////////////////////////////////////
    // Getters //////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}