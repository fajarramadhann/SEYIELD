// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PSYLD} from './pSYLD.sol';
import {YSYLD} from './ySYLD.sol';
import {MockYieldProtocol} from "./MockYieldProtocol.sol";
import {Treasury} from "./Treasury.sol";

error InsufficientBalance();
error InvalidAmount();
error InvalidAddress();
error TransferFailed();
error WithdrawalLocked();
error AlreadyWithdrawn();
error ZeroAddress(string field);

contract FundsVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Immutable addresses
    IERC20 private immutable usdc;
    PSYLD public immutable pSYLD;
    YSYLD public immutable ySYLD;
    Treasury public immutable treasury;
    MockYieldProtocol public immutable yieldProtocol;

    // Constants using uint96 to pack with other state variables
    uint96 private constant LOCK_PERIOD = 30 days;
    uint96 private constant YIELD_RATIO = 7;
    uint96 private constant EARLY_WITHDRAWAL_FEE = 5;
    uint96 private constant BASIC_POINTS = 10000;
    uint96 private constant POOL_DEPLOYMENT_INTERVAL = 24 hours;

    // State variables packed into slots
    struct UserInfo {
        uint128 deposit;
        uint64 depositTime;
        bool hasWithdrawn;
    }
    
    mapping(address => UserInfo) public userInfo;
    uint256 public totalPooledAmount;
    uint256 public lastDeploymentTime;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 fee);
    event YieldDeposited(uint256 amount);
    event YieldHarvested(uint256 amount);
    event PoolDeployed(uint256 amount, uint256 timestamp);

    struct InitialSetup {
        address _initialOwner;
        address _usdc;
        address _yieldProtocol;
        address _treasury;
        address _pSYLD;
        address _ySYLD;
    }

    constructor(InitialSetup memory initParams) Ownable(initParams._initialOwner) {
        usdc = IERC20(initParams._usdc);
        yieldProtocol = MockYieldProtocol(initParams._yieldProtocol);
        treasury = Treasury(initParams._treasury);
        pSYLD = PSYLD(initParams._pSYLD);
        ySYLD = YSYLD(initParams._ySYLD);
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        
        address sender = msg.sender;
        if (usdc.balanceOf(sender) < amount) revert InsufficientBalance();

        unchecked {
            // Safe math not needed due to checks
            totalPooledAmount += amount;
            
            // Mint tokens
            pSYLD.mint(sender, amount);
            uint256 yieldTokens = (amount * YIELD_RATIO) / 100;
            ySYLD.mint(address(this), yieldTokens);
            
            // Update user info
            userInfo[sender] = UserInfo({
                deposit: uint128(amount),
                depositTime: uint64(block.timestamp),
                hasWithdrawn: false
            });
        }

        // Transfer USDC
        usdc.safeTransferFrom(sender, address(this), amount);

        // Auto deploy if interval passed
        if (block.timestamp >= lastDeploymentTime + POOL_DEPLOYMENT_INTERVAL) {
            _deployPool();
        }

        emit Deposited(sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        
        address sender = msg.sender;
        UserInfo storage user = userInfo[sender];
        
        if (pSYLD.balanceOf(sender) < amount) revert InsufficientBalance();

        uint256 fee;
        unchecked {
            // Calculate fee if within lock period
            if (block.timestamp < user.depositTime + LOCK_PERIOD) {
                fee = (amount * EARLY_WITHDRAWAL_FEE) / 100;
            }
            
            uint256 withdrawAmount = amount - fee;
            totalPooledAmount -= amount;
            user.deposit -= uint128(amount);
        }

        // Burn tokens and transfer
        pSYLD.burn(sender, amount);
        if (fee > 0) {
            usdc.safeTransfer(address(treasury), fee);
        }
        usdc.safeTransfer(sender, amount - fee);

        emit Withdrawn(sender, amount - fee, fee);
    }

    function _deployPool() internal {
        uint256 amount = totalPooledAmount;
        if (amount == 0) return;

        address protocolAddress = address(yieldProtocol);
        usdc.approve(protocolAddress, amount);
        yieldProtocol.deposit(amount);

        lastDeploymentTime = block.timestamp;
        totalPooledAmount = 0;

        emit PoolDeployed(amount, block.timestamp);
    }

    function harvestYield() external onlyOwner {
        uint256 yieldAmount = yieldProtocol.claimYield();
        if (yieldAmount > 0) {
            usdc.safeTransfer(address(treasury), yieldAmount);
        }
        emit YieldHarvested(yieldAmount);
    }

    // View functions
    function estimateYield(address user) external view returns (uint256) {
        return yieldProtocol.calculateYield(user);
    }

    function getPooledAmount() external view returns (uint256) {
        return totalPooledAmount;
    }

    function getNextDeploymentTime() external view returns (uint256) {
        return lastDeploymentTime + POOL_DEPLOYMENT_INTERVAL;
    }
}