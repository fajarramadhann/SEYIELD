// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error InvalidToken();
error InvalidAmount();
error InsufficientBalance();
error TransferFailed();
error NoYieldAvailable();
error NotAuthorized();

/// @title MockYieldProtocol
/// @notice Simulates a lending protocol like Aave with fixed 8% APY
contract MockYieldProtocol is ReentrancyGuard {
    IERC20 public immutable usdc;

    uint256 private constant APY = 8;
    uint256 private constant APY_DENOMINATOR = 100;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositTimestamps;

    event Deposited(address indexed depositor, uint256 amount);
    event Withdrawn(address indexed withdrawer, uint256 amount);
    event YieldClaimed(address indexed claimer, uint256 amount);
    event YieldGenerated(uint256 amount);

    constructor(address _usdc) {
        if (_usdc == address(0)) revert InvalidToken();
        usdc = IERC20(_usdc);
    }

    /// @notice Deposit USDC to start earning yield
    /// @param amount Amount of USDC to deposit
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        deposits[msg.sender] += amount;
        depositTimestamps[msg.sender] = block.timestamp;

        if(!usdc.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw deposited USDC
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        if (deposits[msg.sender] < amount) revert InsufficientBalance();

        deposits[msg.sender] -= amount;

        if(!usdc.transfer(msg.sender, amount)) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Calculate accrued yield for an address
    /// @param user Address to calculate yield for
    /// @return Accrued yield amount
    function calculateYield(address user) public view returns (uint256) {
        if (deposits[user] == 0) return 0;

        uint256 timeElapsed = block.timestamp - depositTimestamps[user];
        uint256 principal = deposits[user];


        return (principal * APY * timeElapsed) / (APY_DENOMINATOR * SECONDS_PER_YEAR);
    }

    /// @notice Manually generate yield for testing purposes
    /// @param amount Amount of yield to generate
    function generateYield(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        // Request USDC tokens from owner to simulate yield
        if (!usdc.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        
        emit YieldGenerated(amount);
    }

    /// @notice Claim accrued yield
    /// @return Amount of yield claimed
    function claimYield() external nonReentrant returns (uint256) {
        uint256 yieldAmount = calculateYield(msg.sender);
        if (yieldAmount == 0) revert NoYieldAvailable();

        // Reset deposit timestamp for new yield calculation
        depositTimestamps[msg.sender] = block.timestamp;

        if(!usdc.transfer(msg.sender, yieldAmount)) revert TransferFailed();

        emit YieldClaimed(msg.sender, yieldAmount);
        return yieldAmount;
    }

    function distributeYield(address to) external {
        if(deposits[to] <= 0) revert("Insufficient balance");
        uint256 calculatedYield = calculateYield(to);
        if(calculatedYield <= 0) revert("yield is zero");
        usdc.transfer(to, calculatedYield);
    }
}