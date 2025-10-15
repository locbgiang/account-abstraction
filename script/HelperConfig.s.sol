// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {

    ////////////////////////////////////////////
    // Error ///////////////////////////////////
    ////////////////////////////////////////////
    error HelperConfig__InvalidChainId();

    ////////////////////////////////////////////
    // Types ///////////////////////////////////
    ////////////////////////////////////////////
    struct NetworkConfig {
        address entryPoint;
        address usdc;
        address account;
    }

    ///////////////////////////////////////////////////////////////
    // State Variables ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////

    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    // Update the BURNER_WALLET to your burner wallet!
    //address constant BURNER_WALLET = 

    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    ////////////////////////////////////////////////////////////
    // Functions ///////////////////////////////////////////////
    ////////////////////////////////////////////////////////////

    constructor() {
        // get the sepolia network config
        // get the mainnet config
        // get the zksync config
        // get the arbitrum config
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /////////////////////////////////////////////////////////////////
    // Configs //////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////

    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        // this is v7
        return NetworkConfig({
            entryPoint: 
        })
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // deploy mocks
        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock erc20Mock = new ERC20Mock();
        vm.stopBroadcast();
        console2.log("Mocks deployed!");

        localNetworkConfig = NetworkConfig({
            entryPoint: address(entryPoint),
            usdc: address(erc20Mock),
            account: ANVIL_DEFAULT_ACCOUNT
        });

        return localNetworkConfig;
    }
}