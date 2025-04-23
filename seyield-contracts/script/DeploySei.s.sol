// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {MockUSDC} from "../src/MockUSDC.sol";
import {MockYieldProtocol} from "../src/MockYieldProtocol.sol";
import {PSYLD} from "../src/PSYLD.sol";
import {YSYLD} from "../src/YSYLD.sol";
import {Treasury} from "../src/Treasury.sol";
import {FundsVault} from "../src/Vault.sol";
import {Faucet} from "../src/Faucet.sol";
import {Merchant} from "../src/Merchant.sol";

/**
 * @title DeploySEI
 * @notice Script to deploy all contracts to the SEI testnet (without SEI funding for Faucet)
 * @dev This script deploys all contracts in the correct order and sets up their relationships
 */
contract DeploySEI is Script {
    // Contract instances
    MockUSDC public usdc;
    MockYieldProtocol public yieldProtocol;
    PSYLD public pSYLD;
    YSYLD public ySYLD;
    Treasury public treasury;
    FundsVault public fundsVault;
    Faucet public faucet;
    Merchant public merchant;

    // Deployment addresses
    address public deployer;

    // Constants
    uint256 public constant FAUCET_USDC_AMOUNT = 500_000e6; // 500K USDC
    uint256 public constant TREASURY_USDC_AMOUNT = 200_000e6; // 200K USDC

    function run() public {
        // Get private key from environment variable or use hardcoded one for testing
        uint256 deployerPrivateKey;

        // UNCOMMENT ONE OF THESE OPTIONS:

        // OPTION 1: Use environment variable (recommended for production)
        // deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // OPTION 2: Hardcoded private key (FOR TESTING ONLY - NEVER USE IN PRODUCTION)
        deployerPrivateKey = "dont-steal-my-private-key";
        console2.log("WARNING: Using hardcoded private key for testing. NEVER use in production!");

        deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer address:", deployer);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy token contracts
        deployTokens();

        // Step 2: Deploy core protocol contracts
        deployProtocol();

        // Step 3: Deploy auxiliary contracts
        deployAuxiliary();

        // Step 4: Configure contract relationships
        setupContractRelationships();

        // Step 5: Fund contracts
        fundContracts();

        // End broadcasting transactions
        vm.stopBroadcast();

        // Log deployment summary
        logDeploymentSummary();
    }

    /**
     * @notice Deploy token contracts (USDC, pSYLD, ySYLD)
     */
    function deployTokens() internal {
        console2.log("Deploying token contracts...");

        // Deploy MockUSDC - this will automatically mint 1,000,000 USDC to the deployer
        usdc = new MockUSDC();
        console2.log("MockUSDC deployed at:", address(usdc));
        console2.log("Deployer automatically received 1,000,000 USDC from constructor");

        // Deploy pSYLD token
        pSYLD = new PSYLD();
        console2.log("PSYLD deployed at:", address(pSYLD));

        // Deploy ySYLD token
        ySYLD = new YSYLD();
        console2.log("YSYLD deployed at:", address(ySYLD));
    }

    /**
     * @notice Deploy core protocol contracts (Treasury, YieldProtocol, FundsVault)
     */
    function deployProtocol() internal {
        console2.log("Deploying core protocol contracts...");

        // Deploy Treasury
        treasury = new Treasury(address(usdc));
        console2.log("Treasury deployed at:", address(treasury));

        // Deploy MockYieldProtocol
        yieldProtocol = new MockYieldProtocol(address(usdc));
        console2.log("MockYieldProtocol deployed at:", address(yieldProtocol));

        // Deploy FundsVault
        FundsVault.InitialSetup memory setup = FundsVault.InitialSetup({
            _initialOwner: deployer,
            _usdc: address(usdc),
            _yieldProtocol: address(yieldProtocol),
            _treasury: address(treasury),
            _pSYLD: address(pSYLD),
            _ySYLD: address(ySYLD)
        });

        fundsVault = new FundsVault(setup);
        console2.log("FundsVault deployed at:", address(fundsVault));
    }

    /**
     * @notice Deploy auxiliary contracts (Faucet, Merchant)
     */
    function deployAuxiliary() internal {
        console2.log("Deploying auxiliary contracts...");

        // Deploy Faucet
        faucet = new Faucet(address(usdc));
        console2.log("Faucet deployed at:", address(faucet));

        // Deploy Merchant
        merchant = new Merchant(
            address(usdc),
            address(ySYLD),
            address(fundsVault),
            address(treasury),
            deployer
        );
        console2.log("Merchant deployed at:", address(merchant));
    }

    /**
     * @notice Set up relationships between contracts
     */
    function setupContractRelationships() internal {
        console2.log("Setting up contract relationships...");

        // Set FundsVault in token contracts
        pSYLD.setFundsVault(address(fundsVault));
        ySYLD.setFundsVault(address(fundsVault));

        // Grant Merchant contract permission to use Treasury
        treasury.transferOwnership(address(merchant));
    }

    /**
     * @notice Fund contracts with initial tokens (USDC only, no SEI)
     */
    function fundContracts() internal {
        console2.log("Funding contracts...");

        // Check deployer's USDC balance
        uint256 deployerUsdcBalance = usdc.balanceOf(deployer);
        console2.log("Deployer USDC balance:", deployerUsdcBalance / 1e6, "USDC");

        // Fund Faucet with USDC
        usdc.transfer(address(faucet), FAUCET_USDC_AMOUNT);
        console2.log("Funded Faucet with", FAUCET_USDC_AMOUNT / 1e6, "USDC");

        // Fund Treasury with USDC for initial operations
        usdc.transfer(address(treasury), TREASURY_USDC_AMOUNT);
        console2.log("Funded Treasury with", TREASURY_USDC_AMOUNT / 1e6, "USDC");
    }

    /**
     * @notice Log deployment summary
     */
    function logDeploymentSummary() internal view {
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Network: SEI Testnet");
        console2.log("Deployer:", deployer);
        console2.log("\nToken Contracts:");
        console2.log("- MockUSDC:", address(usdc));
        console2.log("- PSYLD:", address(pSYLD));
        console2.log("- YSYLD:", address(ySYLD));
        console2.log("\nCore Protocol:");
        console2.log("- Treasury:", address(treasury));
        console2.log("- MockYieldProtocol:", address(yieldProtocol));
        console2.log("- FundsVault:", address(fundsVault));
        console2.log("\nAuxiliary Contracts:");
        console2.log("- Faucet:", address(faucet));
        console2.log("- Merchant:", address(merchant));
        console2.log("\nInitial Funding:");
        console2.log("- Faucet USDC:", FAUCET_USDC_AMOUNT / 1e6, "USDC");
        console2.log("- Treasury USDC:", TREASURY_USDC_AMOUNT / 1e6, "USDC");
        console2.log("\nNext Steps:");
        console2.log("1. Update your .env file with the deployed contract addresses");
        console2.log("2. Verify the contracts using 'make verify-sei CONTRACT_ADDRESS=<address> CONTRACT_NAME=<name>'");
        console2.log("=========================\n");
    }
}