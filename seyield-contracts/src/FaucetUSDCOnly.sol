// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FaucetUSDCOnly
 * @notice A faucet contract that only distributes USDC tokens (no SEI)
 * @dev This is a simplified version of the Faucet contract
 */
contract FaucetUSDCOnly is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;

    uint256 public constant USDC_AMOUNT = 1_000e6; // 1000 USDC
    uint256 public constant CLAIM_INTERVAL = 24 hours;

    mapping(address => uint256) public lastClaimTime;

    event TokensClaimed(address indexed user, uint256 usdcAmount);
    event TokensDeposited(address indexed depositor, uint256 usdcAmount);

    constructor(address _usdc) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        usdc = IERC20(_usdc);
    }

    /**
     * @notice Allows users to claim USDC tokens from the faucet
     * @dev Users can only claim once per CLAIM_INTERVAL
     */
    function claimTokens() external nonReentrant {
        // Cache msg.sender for gas optimization
        address sender = msg.sender;

        // Cache current timestamp for gas optimization
        uint256 currentTime = block.timestamp;

        // If this is the first claim, allow it
        uint256 lastClaim = lastClaimTime[sender];
        if (lastClaim != 0) {
            require(
                currentTime >= lastClaim + CLAIM_INTERVAL,
                "Wait 24h between claims"
            );
        }

        // Cache contract address for gas optimization
        address self = address(this);

        require(
            usdc.balanceOf(self) >= USDC_AMOUNT,
            "Insufficient USDC balance"
        );

        // Update state before external calls (reentrancy protection)
        lastClaimTime[sender] = currentTime;

        // External calls after state changes
        usdc.transfer(sender, USDC_AMOUNT);

        emit TokensClaimed(sender, USDC_AMOUNT);
    }

    /**
     * @notice Allows the owner to deposit USDC tokens into the faucet
     * @param usdcAmount The amount of USDC to deposit
     */
    function depositTokens(uint256 usdcAmount) external onlyOwner {
        // Cache msg.sender for gas optimization
        address sender = msg.sender;

        if (usdcAmount > 0) {
            usdc.transferFrom(sender, address(this), usdcAmount);
        }
        emit TokensDeposited(sender, usdcAmount);
    }

    /**
     * @notice Allows the owner to withdraw USDC tokens from the faucet
     * @param usdcAmount The amount of USDC to withdraw
     */
    function withdrawTokens(uint256 usdcAmount) external onlyOwner {
        // Cache msg.sender for gas optimization
        address sender = msg.sender;

        if (usdcAmount > 0) {
            usdc.transfer(sender, usdcAmount);
        }
    }

    /**
     * @notice Checks if a user can claim tokens
     * @param user The address of the user to check
     * @return Whether the user can claim tokens
     */
    function getClaimableAmount(address user) external view returns (bool) {
        uint256 lastClaim = lastClaimTime[user];
        // If user has never claimed, they can claim immediately
        if (lastClaim == 0) return true;
        return block.timestamp >= lastClaim + CLAIM_INTERVAL;
    }
}
