// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    // make sure you trust this user - don't run this on Mainnet
    address constant RANDOM_APPROVER = 0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC;

    /**
     * designed to create and send a 'packed user operation' on the Ethereum blockchain.
     * a key component of EIP-4337 (account abstraction).
     * 
     * Think of it like creating a "smart transaction" that can be executed by a
     * smart contract wallet instead of a regular EOA (externally owned account).
     */
    function run () public {
        // setup
        // get network-specific addresses (like USDC contract address on Arbitrum)
        // USDC for example has different addresses on different chains
        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().usdc; // arbitrum mainnnet USDC address
        
        // Specifies how much ETH to send.
        // Set to 0 because we're calling USDC's approve() function,
        // which doesn't require ETH payment.
        // why are we using USDC specifically?
        uint256 value = 0;

        // gets smart contract wallet address
        // Example: MetaMask has address 0x123 but smart contract wallet might be 0x456
        // this finds the latest deployed version
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment(
            "MinimalAccount",
            block.chainid
        );

        // encodes the actual function call you want to make
        // example: to approve Uniswap to send 1000 USDC from your wallet,
        // you need to call approve([Uniswap token contract address], 1000e6)
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
        
        // wraps your function call in the smart wallet's execute() function.
        // your smart wallet needs to know 
        //'execute this approve call on the USDC contract with 0 ETH value'
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        // creates the complete user operation with all the required field
        // (gas limit, fees, signature)
        // like filling out a complete transaction form with gas price, nonce, and signature
        PackedUserOperation memory userOp = generateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            minimalAccountAddress
        );

        // The PackeduserOperation is added to an array (ops) with a single element
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // handleOps: the handleOps function of the IEntryPoint contract is called with:
        // ops: the array of packed user operations
        // payable(HelperConfig.getConfig().account): the account that will pay for the operation
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
    }

    /**
     * This function generates a signed user operation that can be sent to an IEntryPoint
     * contract for execution.
     * This is part of the Account Abstraction mechanism, where smart contract wallets
     * can execute transactions.
     * @param callData The data for the function call that the user operation will execute
     * @param config A configurtion object containing network-specific details
     * @param minimalAccount The address of the smart contract wallet that will execute the operation
     */
    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // 1. Generate the unsigned data
        // retrieves the nonce for the smart contract wallet from the EntryPoint contract
        // Nonces prevent replay attacks
        // They ensure each user operation can only be executed once and in the correct order
        // First operation nonce = 0, second operation nonce = 1... and so forth
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(minimalAccount, 0);

        // This line calls the internal helper function _generateUnsignedUserOperation
        // to create a PackedUserOperationStruct with all the neccessary fields
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        // 2. Get the userOp hash
        // creates the standardized hash of the user operation by calling the EntryPoint 
        // contracts getUserOpHash() function
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);

        // userOpHash then get convereted to an 
        // Ethereum signed message hash 
        // (adds the "\x19Ethereum Signed Message:\n32 prefix")
        // which is what actually gets signed
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3. Sign it
        // The function sign the digest (user operation hash) to produce the signature components
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        // If chain ID is 31337 (indicating a local Anvil testnet)
        if (block.chainid == 31337) {
            // it uses a hardcoded private key (ANVIL_DEFAULT_KEY) to sign the hash
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            // for other networks, it uses the private key associated with config.account
            (v, r, s) = vm.sign(config.account, digest);
        }

        // The signature components (r,s,v) are concatenated into a single bytes
        // value using abi.encodePacked. This is the format expected by the IEntryPoint contract
        userOp.signature = abi.encodePacked(r, s, v); // note the order
        return userOp;
    }

    /**
     * This function _generateUnsignedUserOperation creates a PackedUserOperation struct
     * with all the necessary fields for EIP-4337 Account Abstraction, but without a signature
     * @param callData The actual function call to execute (USDC approve in this case)
     * @param sender The smart contract wallet address that will execute the operation
     * @param nonce For replay protection (ensures operations execute in order)
     * 
     * This function gets called by the public generateSignedUserOperation
     */
    function _generateUnsignedUserOperation(
        bytes memory callData, 
        address sender, 
        uint256 nonce
    ) 
        internal
        pure
        returns (PackedUserOperation memory) 
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}