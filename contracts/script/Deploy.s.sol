// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {DepositEscrow} from "../src/DepositEscrow.sol";
import {console} from "forge-std/console.sol";

//Dry Run:
// forge script script/Deploy.s.sol:DeployDepositEscrow \
//   --rpc-url https://rpc-amoy.polygon.technology/ \
//   -vvv

//Testnet Amoy:
// forge script script/Deploy.s.sol:DeployDepositEscrow \
//   --rpc-url https://rpc-amoy.polygon.technology/ \
//   --broadcast \
//   --verify \
//   -vvvv

contract DeployDepositEscrow is Script {
    function run() external returns (DepositEscrow) {        
        address resolver = vm.envAddress("RESOLVER_ADDRESS");
        uint256 platformFee = vm.envUint("PLATFORM_FEE");
        address usdcToken = vm.envAddress("USDC_TOKEN_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        console.log("=================================");
        console.log("Deploying DepositEscrow");
        console.log("=================================");
        console.log("Network: Polygon Amoy");
        console.log("Resolver:", resolver);
        console.log("Platform Fee:", platformFee);
        console.log("USDC Token:", usdcToken);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        DepositEscrow escrow = new DepositEscrow(resolver, platformFee, usdcToken);
        
        vm.stopBroadcast();
        
        console.log("=================================");
        console.log("SUCCESS!");
        console.log("=================================");
        console.log("DepositEscrow:", address(escrow));
        console.log("");
        
        return escrow;
    }
}