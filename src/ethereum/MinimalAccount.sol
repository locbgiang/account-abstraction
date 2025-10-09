// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
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
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max("")};
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