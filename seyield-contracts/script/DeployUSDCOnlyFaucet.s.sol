// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {FaucetUSDCOnly} from "../src/FaucetUSDCOnly.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

/**
 * @title DeployUSDCOnlyFaucet
 * @notice Script to deploy the USDC-only faucet
 */
contract DeployUSDCOnlyFaucet is Script {
    // Contract instances
    FaucetUSDCOnly public faucet;
    
    // Deployment addresses
    address public deployer;
    address public usdcAddress;

    // Constants
    uint256 public constant FAUCET_USDC_AMOUNT = 500_000e6; // 500K USDC

    function run() external {
        uint256 deployerPrivateKey = uint256(
            "dont-steal-my-private-key"
        );
        console2.log("WARNING: Using hardcoded private key. NEVER use in production!");

        // 2. Hardcoded USDC mock address (replace ini kalau mau dari .env)
        usdcAddress = 0x855036d27d0B0691ac6FC8A958fF90d394Db9b62;

        // 3. Get deployer address
        deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        // 4. Start broadcasting tx
        vm.startBroadcast(deployerPrivateKey);

        // 5. Deploy faucet contract
        faucet = new FaucetUSDCOnly(usdcAddress);
        console2.log("FaucetUSDCOnly deployed at:", address(faucet));

        // 6. Fund faucet with USDC if possible
        MockUSDC usdc = MockUSDC(usdcAddress);
        uint256 deployerBalance = usdc.balanceOf(deployer);
        if (deployerBalance >= FAUCET_USDC_AMOUNT) {
            usdc.approve(address(faucet), FAUCET_USDC_AMOUNT);
            faucet.depositTokens(FAUCET_USDC_AMOUNT);
            console2.log("Funded faucet with", FAUCET_USDC_AMOUNT / 1e6, "USDC");
        } else {
            console2.log("Not enough USDC. You have:", deployerBalance / 1e6, "USDC");
        }

        vm.stopBroadcast();

        // 7. Final log
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Deployer:       ", deployer);
        console2.log("USDC Address:   ", usdcAddress);
        console2.log("Faucet Address: ", address(faucet));
        console2.log("================================\n");
    }
}
