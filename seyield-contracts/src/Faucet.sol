// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Faucet is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;

    uint256 public constant USDC_AMOUNT = 1_000e6; // 1000 USDC
    uint256 public constant SEI_AMOUNT = 1 ether; // 1 SEI
    uint256 public constant CLAIM_INTERVAL = 24 hours;

    mapping(address => uint256) public lastClaimTime;

    event TokensClaimed(address indexed user, uint256 usdcAmount, uint256 seiAmount);
    event TokensDeposited(address indexed depositor, uint256 usdcAmount, uint256 seiAmount);

    constructor(address _usdc) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        usdc = IERC20(_usdc);
    }

    receive() external payable {}

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

        require(
            self.balance >= SEI_AMOUNT,
            "Insufficient SEI balance"
        );

        // Update state before external calls (reentrancy protection)
        lastClaimTime[sender] = currentTime;

        // External calls after state changes
        usdc.transfer(sender, USDC_AMOUNT);
        (bool success,) = payable(sender).call{value: SEI_AMOUNT}("");
        require(success, "SEI transfer failed");

        emit TokensClaimed(sender, USDC_AMOUNT, SEI_AMOUNT);
    }

    function depositTokens(uint256 usdcAmount) external payable onlyOwner {
        // Cache msg.sender for gas optimization
        address sender = msg.sender;

        if (usdcAmount > 0) {
            usdc.transferFrom(sender, address(this), usdcAmount);
        }
        emit TokensDeposited(sender, usdcAmount, msg.value);
    }

    function withdrawTokens(uint256 usdcAmount, uint256 seiAmount) external onlyOwner {
        // Cache msg.sender for gas optimization
        address sender = msg.sender;

        if (usdcAmount > 0) {
            usdc.transfer(sender, usdcAmount);
        }

        if (seiAmount > 0) {
            (bool success,) = payable(sender).call{value: seiAmount}("");
            require(success, "SEI transfer failed");
        }
    }

    function getClaimableAmount(address user) external view returns (bool) {
        uint256 lastClaim = lastClaimTime[user];
        // If user has never claimed, they can claim immediately
        if (lastClaim == 0) return true;
        return block.timestamp >= lastClaim + CLAIM_INTERVAL;
    }
}