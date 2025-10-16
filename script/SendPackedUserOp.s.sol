// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "@forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

contract SendPackedUserOp is Script {
    function run () public {
        // setup
        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().usdc; // arbitrum mainnnet USDC address
        uint256 value = 0;
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment(
            "MinimalAccount",
            block.chainid
        );

        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
    }
}