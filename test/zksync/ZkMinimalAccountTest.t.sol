// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";

contract ZkMinimalAccountTest is Test {

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;

    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant AMOUNT = 1e18;

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

        
    }
}