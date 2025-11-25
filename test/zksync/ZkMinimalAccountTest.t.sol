// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {
    Transaction, 
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

// OZ imports
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Foundry Devops
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

contract ZkMinimalAccountTest is Test {

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;

    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }

    function testOwnerCanExecuteCommands() public {
        // ARRANGE

        // set the destination address to the USDC mock contract
        // this is where the transaction will be sent to
        address dest = address(usdc);

        // set the ETH value to send with the transaction to 0
        // since this is jus calling the function (not transfering) no value is needed
        uint256 value = 0;

        // encodes the funciton call datat for mint(address, uint256)
        // will mint AMOUNT (1e18) toknes to the minimalAccount address
        // this is the actual operation the transaction will execute
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        
        // creates an unsigned zkSync transaction structure with 
        // 1. minimalAccount.Owner() - the transaction sender (ANVIL_DEFAULT_ACCOUNT)
        // 2. 113 - transaction type indentifier for zkSync
        // 3. dest - the USDC contract address (target)
        // 4. value - 0 eth
        // 5 functionData - the encoded mint function call
        Transaction memory transaction = 
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        // act

        // set the next call to minimalAccount.owner()
        vm.prank(minimalAccount.owner());
        // executeTransaction
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testZkValidateTransaction() public {
        // arrange

        // the same transaction parameters as the previous test
        // (mint USDC to minimalAccount)
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // creates an unsigned transaction structure
        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        // signs the transaction with the owner's private key
        // this is the key difference from the first test -this transaction now has a valid signature 
        transaction = _signTransaction(transaction);

        // act

        // sets msg.sender to BOOTLOADER_FORMAL_ADDRESS for the next call
        // this passes the requireFromBootLoader modifier check
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);

        // calls validateTransaction() which internally calls _validateTransaction()
        // inside _validateTransaction():
        //      1. incement nonces
        //      2. check balance
        //      3. verifies signature
        //      4. returns magic value
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // assert

        // verifies that validation succeeded by checking the returned magic value
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    ////////////////////////////////////////////////////
    // Helpers /////////////////////////////////////////
    ////////////////////////////////////////////////////

    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        // bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType, // type 113 (0x71)
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}