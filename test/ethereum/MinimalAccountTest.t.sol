// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "../../script/SendPackedUserOp.s.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title MinimalAccountTest
 * @author Loc Giang
 * forge test --match-path test/ethereum/**
 */
contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address randomUser = makeAddr("randomUser");
    
    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, 
            address(minimalAccount),
            AMOUNT
        );

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, 
            address(minimalAccount),
            AMOUNT
        );
        
        // act
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidationOfUserOp() public {
        // arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        // arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(),
            address(minimalAccount)
        );

        vm.deal(address(minimalAccount), 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // act
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        // assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}