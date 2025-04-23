// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {YSYLD} from "./YSYLD.sol";
import {FundsVault} from "./Vault.sol";
import {Treasury} from "./Treasury.sol";

/**
 * @title Merchant
 * @notice Contract for managing merchant listings and purchases in the SEYIELD marketplace
 * @dev Integrates with FundsVault, YSYLD, and Treasury contracts
 */
contract Merchant is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Immutable addresses for gas savings
    IERC20 public immutable usdc;
    YSYLD public immutable ySYLD;
    FundsVault public immutable fundsVault;
    Treasury public immutable treasury;

    // Constants
    uint256 private constant PLATFORM_FEE_PERCENT = 2; // 2% platform fee

    // Merchant data structure
    struct MerchantInfo {
        bool isRegistered;
        string name;
        string description;
        uint256 totalSales;
        uint256 pendingPayment;
    }

    // Item/Service data structure
    struct Item {
        uint256 id;
        address merchant;
        string name;
        string description;
        uint256 price; // in USDC
        uint256 requiredYSYLD; // minimum ySYLD balance required to purchase
        bool isActive;
    }

    // Purchase data structure
    struct Purchase {
        uint256 id;
        address buyer;
        address merchant;
        uint256 itemId;
        uint256 price;
        uint256 timestamp;
        bool isPaid;
    }

    // State variables
    mapping(address => MerchantInfo) public merchants;
    mapping(uint256 => Item) public items;
    mapping(uint256 => Purchase) public purchases;
    
    address[] public registeredMerchants;
    uint256 public itemCount;
    uint256 public purchaseCount;
    uint256 public platformFees;

    // Events
    event MerchantRegistered(address indexed merchant, string name);
    event MerchantUpdated(address indexed merchant, string name);
    event ItemListed(uint256 indexed itemId, address indexed merchant, uint256 price, uint256 requiredYSYLD);
    event ItemUpdated(uint256 indexed itemId, uint256 price, uint256 requiredYSYLD, bool isActive);
    event ItemPurchased(uint256 indexed purchaseId, address indexed buyer, address indexed merchant, uint256 itemId, uint256 price);
    event MerchantPaid(address indexed merchant, uint256 amount);
    event PlatformFeesCollected(uint256 amount);

    /**
     * @notice Constructor to initialize the Merchant contract
     * @param _usdc Address of the USDC token
     * @param _ySYLD Address of the ySYLD token
     * @param _fundsVault Address of the FundsVault contract
     * @param _treasury Address of the Treasury contract
     * @param _initialOwner Address of the initial owner
     */
    constructor(
        address _usdc,
        address _ySYLD,
        address _fundsVault,
        address _treasury,
        address _initialOwner
    ) Ownable(_initialOwner) {
        if (_usdc == address(0)) revert("Zero USDC address");
        if (_ySYLD == address(0)) revert("Zero ySYLD address");
        if (_fundsVault == address(0)) revert("Zero FundsVault address");
        if (_treasury == address(0)) revert("Zero Treasury address");

        usdc = IERC20(_usdc);
        ySYLD = YSYLD(_ySYLD);
        fundsVault = FundsVault(_fundsVault);
        treasury = Treasury(_treasury);
    }

    /**
     * @notice Register a new merchant
     * @param name Merchant name
     * @param description Merchant description
     */
    function registerMerchant(string calldata name, string calldata description) external nonReentrant {
        address sender = msg.sender;
        require(!merchants[sender].isRegistered, "Already registered");
        require(bytes(name).length > 0, "Name required");

        merchants[sender] = MerchantInfo({
            isRegistered: true,
            name: name,
            description: description,
            totalSales: 0,
            pendingPayment: 0
        });

        registeredMerchants.push(sender);
        emit MerchantRegistered(sender, name);
    }

    /**
     * @notice Update merchant information
     * @param name Updated merchant name
     * @param description Updated merchant description
     */
    function updateMerchant(string calldata name, string calldata description) external {
        address sender = msg.sender;
        require(merchants[sender].isRegistered, "Not registered");
        require(bytes(name).length > 0, "Name required");

        merchants[sender].name = name;
        merchants[sender].description = description;

        emit MerchantUpdated(sender, name);
    }

    /**
     * @notice List a new item or service
     * @param name Item name
     * @param description Item description
     * @param price Item price in USDC
     * @param requiredYSYLD Minimum ySYLD balance required to purchase
     * @return itemId The ID of the newly created item
     */
    function listItem(
        string calldata name,
        string calldata description,
        uint256 price,
        uint256 requiredYSYLD
    ) external nonReentrant returns (uint256) {
        address sender = msg.sender;
        require(merchants[sender].isRegistered, "Not registered");
        require(bytes(name).length > 0, "Name required");
        require(price > 0, "Price must be > 0");

        itemCount++;
        uint256 newItemId = itemCount;

        items[newItemId] = Item({
            id: newItemId,
            merchant: sender,
            name: name,
            description: description,
            price: price,
            requiredYSYLD: requiredYSYLD,
            isActive: true
        });

        emit ItemListed(newItemId, sender, price, requiredYSYLD);
        return newItemId;
    }

    /**
     * @notice Update an existing item
     * @param itemId ID of the item to update
     * @param price Updated price in USDC
     * @param requiredYSYLD Updated minimum ySYLD balance required
     * @param isActive Whether the item is active or not
     */
    function updateItem(
        uint256 itemId,
        uint256 price,
        uint256 requiredYSYLD,
        bool isActive
    ) external {
        require(itemId > 0 && itemId <= itemCount, "Invalid item ID");
        Item storage item = items[itemId];
        require(item.merchant == msg.sender, "Not item owner");
        require(price > 0, "Price must be > 0");

        item.price = price;
        item.requiredYSYLD = requiredYSYLD;
        item.isActive = isActive;

        emit ItemUpdated(itemId, price, requiredYSYLD, isActive);
    }

    /**
     * @notice Purchase an item using ySYLD eligibility
     * @param itemId ID of the item to purchase
     */
    function purchaseItem(uint256 itemId) external nonReentrant {
        address sender = msg.sender;
        require(itemId > 0 && itemId <= itemCount, "Invalid item ID");
        
        Item storage item = items[itemId];
        require(item.isActive, "Item not available");
        
        // Check if user has enough ySYLD balance to be eligible
        uint256 ySYLDBalance = ySYLD.balanceOf(sender);
        require(ySYLDBalance >= item.requiredYSYLD, "Insufficient ySYLD balance");
        
        // Create purchase record
        purchaseCount++;
        uint256 purchaseId = purchaseCount;
        
        purchases[purchaseId] = Purchase({
            id: purchaseId,
            buyer: sender,
            merchant: item.merchant,
            itemId: itemId,
            price: item.price,
            timestamp: block.timestamp,
            isPaid: false
        });
        
        // Update merchant's pending payment
        uint256 platformFee = (item.price * PLATFORM_FEE_PERCENT) / 100;
        uint256 merchantPayment = item.price - platformFee;
        
        merchants[item.merchant].pendingPayment += merchantPayment;
        merchants[item.merchant].totalSales += item.price;
        platformFees += platformFee;
        
        emit ItemPurchased(purchaseId, sender, item.merchant, itemId, item.price);
    }

    /**
     * @notice Pay a merchant for their sales
     * @param merchantAddress Address of the merchant to pay
     */
    function payMerchant(address merchantAddress) external onlyOwner nonReentrant {
        require(merchants[merchantAddress].isRegistered, "Not a registered merchant");
        
        uint256 pendingAmount = merchants[merchantAddress].pendingPayment;
        require(pendingAmount > 0, "No pending payment");
        
        // Reset pending payment before transfer
        merchants[merchantAddress].pendingPayment = 0;
        
        // Transfer USDC from treasury to merchant
        treasury.transferUSDC(merchantAddress, pendingAmount);
        
        emit MerchantPaid(merchantAddress, pendingAmount);
    }

    /**
     * @notice Collect platform fees to treasury
     */
    function collectPlatformFees() external onlyOwner nonReentrant {
        uint256 feesToCollect = platformFees;
        require(feesToCollect > 0, "No fees to collect");
        
        // Reset platform fees before transfer
        platformFees = 0;
        
        // No need to transfer as fees are already in the treasury
        emit PlatformFeesCollected(feesToCollect);
    }

    /**
     * @notice Get merchant information
     * @param merchantAddress Address of the merchant
     * @return isRegistered Whether the merchant is registered
     * @return name Merchant name
     * @return description Merchant description
     * @return totalSales Total sales amount
     * @return pendingPayment Pending payment amount
     */
    function getMerchantInfo(address merchantAddress) external view returns (
        bool isRegistered,
        string memory name,
        string memory description,
        uint256 totalSales,
        uint256 pendingPayment
    ) {
        MerchantInfo storage merchant = merchants[merchantAddress];
        return (
            merchant.isRegistered,
            merchant.name,
            merchant.description,
            merchant.totalSales,
            merchant.pendingPayment
        );
    }

    /**
     * @notice Get item information
     * @param itemId ID of the item
     * @return id Item ID
     * @return merchant Merchant address
     * @return name Item name
     * @return description Item description
     * @return price Item price in USDC
     * @return requiredYSYLD Minimum ySYLD balance required
     * @return isActive Whether the item is active
     */
    function getItemInfo(uint256 itemId) external view returns (
        uint256 id,
        address merchant,
        string memory name,
        string memory description,
        uint256 price,
        uint256 requiredYSYLD,
        bool isActive
    ) {
        require(itemId > 0 && itemId <= itemCount, "Invalid item ID");
        Item storage item = items[itemId];
        return (
            item.id,
            item.merchant,
            item.name,
            item.description,
            item.price,
            item.requiredYSYLD,
            item.isActive
        );
    }

    /**
     * @notice Get purchase information
     * @param purchaseId ID of the purchase
     * @return id Purchase ID
     * @return buyer Buyer address
     * @return merchant Merchant address
     * @return itemId Item ID
     * @return price Purchase price
     * @return timestamp Purchase timestamp
     * @return isPaid Whether the purchase has been paid to the merchant
     */
    function getPurchaseInfo(uint256 purchaseId) external view returns (
        uint256 id,
        address buyer,
        address merchant,
        uint256 itemId,
        uint256 price,
        uint256 timestamp,
        bool isPaid
    ) {
        require(purchaseId > 0 && purchaseId <= purchaseCount, "Invalid purchase ID");
        Purchase storage purchase = purchases[purchaseId];
        return (
            purchase.id,
            purchase.buyer,
            purchase.merchant,
            purchase.itemId,
            purchase.price,
            purchase.timestamp,
            purchase.isPaid
        );
    }

    /**
     * @notice Get the number of registered merchants
     * @return The count of registered merchants
     */
    function getMerchantCount() external view returns (uint256) {
        return registeredMerchants.length;
    }

    /**
     * @notice Check if a user is eligible to purchase an item
     * @param user Address of the user
     * @param itemId ID of the item
     * @return Whether the user is eligible to purchase the item
     */
    function isEligibleForPurchase(address user, uint256 itemId) external view returns (bool) {
        require(itemId > 0 && itemId <= itemCount, "Invalid item ID");
        Item storage item = items[itemId];
        
        if (!item.isActive) return false;
        
        uint256 ySYLDBalance = ySYLD.balanceOf(user);
        return ySYLDBalance >= item.requiredYSYLD;
    }
}
