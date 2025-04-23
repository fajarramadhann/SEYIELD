// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Treasury is Ownable {
    // Using direct IERC20 calls for simplicity

    IERC20 public immutable usdc;

    constructor(address _usdc) Ownable(msg.sender) {
        require(_usdc != address(0), "Zero address");
        usdc = IERC20(_usdc);
    }

    function collectFee(uint256 amount) external {
        // Cache msg.sender for gas optimization
        address sender = msg.sender;
        usdc.transferFrom(sender, address(this), amount);
    }

    function transferUSDC(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero address");
        usdc.transfer(to, amount);
    }

    // Removed duplicate function (distribute) that does the same as transferUSDC
}