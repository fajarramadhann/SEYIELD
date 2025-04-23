// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {FaucetUSDCOnly} from "../src/FaucetUSDCOnly.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FundFaucetNoMint
 * @notice Script to fund the faucet with USDC (without trying to mint)
 */
contract FundFaucetNoMint is Script {
    // Constants
    uint256 public constant FAUCET_USDC_AMOUNT = 100_000e6; // 500K USDC
    
    // Hardcoded addresses (update these with your actual addresses)
    address public constant USDC_ADDRESS = 0x855036d27d0B0691ac6FC8A958fF90d394Db9b62;
    address public constant FAUCET_ADDRESS = 0x56fCEf10AAE54E7e7325eF6Eb1C1eF175C7034aD;

    function run() external {
        uint256 deployerPrivateKey = uint256(
            "dont-steal-my-private-key"
        );
        console2.log("WARNING: Using hardcoded private key. NEVER use in production!");

        // Get the private key from the command line
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deployer:", deployer);
        console2.log("USDC Address:", USDC_ADDRESS);
        console2.log("Faucet Address:", FAUCET_ADDRESS);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the USDC contract (using IERC20 interface instead of MockUSDC)
        IERC20 usdc = IERC20(USDC_ADDRESS);
        
        // Check USDC balance of deployer
        uint256 deployerBalance = usdc.balanceOf(deployer);
        console2.log("Deployer USDC balance:", deployerBalance / 1e6, "USDC");
        
        // Check USDC balance of faucet
        uint256 faucetBalance = usdc.balanceOf(FAUCET_ADDRESS);
        console2.log("Faucet USDC balance before funding:", faucetBalance / 1e6, "USDC");
        
        // Check if deployer has enough USDC
        require(deployerBalance >= FAUCET_USDC_AMOUNT, "Insufficient USDC balance to fund the faucet.");
        
        // Approve the faucet to spend USDC
        console2.log("Approving faucet to spend", FAUCET_USDC_AMOUNT / 1e6, "USDC");
        usdc.approve(FAUCET_ADDRESS, FAUCET_USDC_AMOUNT);
        
        // Fund the faucet
        console2.log("Funding faucet with", FAUCET_USDC_AMOUNT / 1e6, "USDC");
        FaucetUSDCOnly faucet = FaucetUSDCOnly(FAUCET_ADDRESS);
        faucet.depositTokens(FAUCET_USDC_AMOUNT);
        
        // Check USDC balance of faucet after funding
        faucetBalance = usdc.balanceOf(FAUCET_ADDRESS);
        console2.log("Faucet USDC balance after funding:", faucetBalance / 1e6, "USDC");
        
        console2.log("\n=== FUNDING SUMMARY ===");
        console2.log("Faucet funded with", FAUCET_USDC_AMOUNT / 1e6, "USDC");
        console2.log("Faucet can now handle", FAUCET_USDC_AMOUNT / 1000e6, "claims of 1000 USDC each");
        console2.log("======================\n");
        
        vm.stopBroadcast();
    }
}
