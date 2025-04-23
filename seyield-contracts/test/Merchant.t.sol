// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Merchant} from "../src/Merchant.sol";
import {FundsVault} from "../src/Vault.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {MockYieldProtocol} from "../src/MockYieldProtocol.sol";
import {PSYLD} from "../src/PSYLD.sol";
import {YSYLD} from "../src/YSYLD.sol";
import {Treasury} from "../src/Treasury.sol";

contract MerchantTest is Test {
    Merchant public merchant;
    FundsVault public vault;
    MockUSDC public usdc;
    MockYieldProtocol public yieldProtocol;
    PSYLD public pSYLD;
    YSYLD public ySYLD;
    Treasury public treasury;

    address public constant OWNER = address(0x1);
    address public constant USER = address(0x2);
    address public constant MERCHANT_ADDR = address(0x3);
    uint256 public constant INITIAL_BALANCE = 100_000e6; // 100,000 USDC
    uint256 public constant DEPOSIT_AMOUNT = 1_000e6; // 1,000 USDC
    uint256 public constant ITEM_PRICE = 100e6; // 100 USDC

    event MerchantRegistered(address indexed merchant, string name);
    event ItemListed(uint256 indexed itemId, address indexed merchant, uint256 price, uint256 requiredYSYLD);
    event ItemPurchased(uint256 indexed purchaseId, address indexed buyer, address indexed merchant, uint256 itemId, uint256 price);
    event MerchantPaid(address indexed merchant, uint256 amount);

    function setUp() public {
        vm.startPrank(OWNER);

        // Deploy core contracts
        usdc = new MockUSDC();
        pSYLD = new PSYLD();
        ySYLD = new YSYLD();
        treasury = new Treasury(address(usdc));
        yieldProtocol = new MockYieldProtocol(address(usdc));

        // Setup FundsVault
        FundsVault.InitialSetup memory setup = FundsVault.InitialSetup({
            _initialOwner: OWNER,
            _usdc: address(usdc),
            _yieldProtocol: address(yieldProtocol),
            _treasury: address(treasury),
            _pSYLD: address(pSYLD),
            _ySYLD: address(ySYLD)
        });

        vault = new FundsVault(setup);

        pSYLD.setFundsVault(address(vault));
        ySYLD.setFundsVault(address(vault));

        // Deploy Merchant contract
        merchant = new Merchant(
            address(usdc),
            address(ySYLD),
            address(vault),
            address(treasury),
            OWNER
        );

        // Transfer initial USDC to USER and MERCHANT
        usdc.transfer(USER, INITIAL_BALANCE);
        usdc.transfer(MERCHANT_ADDR, INITIAL_BALANCE);

        // Fund treasury for merchant payments
        usdc.transfer(address(treasury), INITIAL_BALANCE);

        vm.stopPrank();
    }

    function testMerchantRegistration() public {
        vm.startPrank(MERCHANT_ADDR);

        vm.expectEmit(true, true, true, true);
        emit MerchantRegistered(MERCHANT_ADDR, "Test Merchant");

        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        (bool isRegistered, string memory name, , , ) = merchant.getMerchantInfo(MERCHANT_ADDR);

        assertTrue(isRegistered);
        assertEq(name, "Test Merchant");

        vm.stopPrank();
    }

    function testItemListing() public {
        // First register the merchant
        vm.startPrank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.expectEmit(true, true, true, true);
        emit ItemListed(1, MERCHANT_ADDR, ITEM_PRICE, 70e6);

        uint256 itemId = merchant.listItem(
            "Test Item",
            "A test item for sale",
            ITEM_PRICE,
            70e6 // Required ySYLD balance (7% of 1000 USDC deposit)
        );

        assertEq(itemId, 1);

        (
            uint256 id,
            address merchantAddr,
            string memory name,
            ,
            uint256 price,
            uint256 requiredYSYLD,
            bool isActive
        ) = merchant.getItemInfo(itemId);

        assertEq(id, 1);
        assertEq(merchantAddr, MERCHANT_ADDR);
        assertEq(name, "Test Item");
        assertEq(price, ITEM_PRICE);
        assertEq(requiredYSYLD, 70e6);
        assertTrue(isActive);

        vm.stopPrank();
    }

    function testItemPurchase() public {
        // Setup: Register merchant and list item
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.prank(MERCHANT_ADDR);
        uint256 itemId = merchant.listItem(
            "Test Item",
            "A test item for sale",
            ITEM_PRICE,
            0 // Set required ySYLD balance to 0 for testing
        );

        // User purchases the item
        vm.startPrank(USER);

        vm.expectEmit(true, true, true, true);
        emit ItemPurchased(1, USER, MERCHANT_ADDR, itemId, ITEM_PRICE);

        merchant.purchaseItem(itemId);

        (
            ,
            address buyer,
            address merchantAddr,
            uint256 purchasedItemId,
            uint256 price,
            ,
            bool isPaid
        ) = merchant.getPurchaseInfo(1);

        assertEq(buyer, USER);
        assertEq(merchantAddr, MERCHANT_ADDR);
        assertEq(purchasedItemId, itemId);
        assertEq(price, ITEM_PRICE);
        assertFalse(isPaid);

        vm.stopPrank();

        // Check merchant's pending payment
        (,,, , uint256 pendingPayment) = merchant.getMerchantInfo(MERCHANT_ADDR);
        assertEq(pendingPayment, ITEM_PRICE - (ITEM_PRICE * 2 / 100)); // Price minus 2% platform fee
    }

    function testMerchantPayment() public {
        // Setup: Register merchant, list item, and make a purchase
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.prank(MERCHANT_ADDR);
        uint256 itemId = merchant.listItem("Test Item", "A test item for sale", ITEM_PRICE, 0);

        vm.prank(USER);
        merchant.purchaseItem(itemId);

        // Get merchant's pending payment before payment
        (,,, , uint256 pendingPaymentBefore) = merchant.getMerchantInfo(MERCHANT_ADDR);

        // Get merchant's USDC balance before payment
        uint256 merchantBalanceBefore = usdc.balanceOf(MERCHANT_ADDR);

        // Transfer ownership of Treasury to Merchant contract for testing
        vm.prank(OWNER);
        treasury.transferOwnership(address(merchant));

        // Owner pays the merchant
        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true);
        emit MerchantPaid(MERCHANT_ADDR, pendingPaymentBefore);

        merchant.payMerchant(MERCHANT_ADDR);

        vm.stopPrank();

        // Get merchant's pending payment after payment
        (,,, , uint256 pendingPaymentAfter) = merchant.getMerchantInfo(MERCHANT_ADDR);

        // Get merchant's USDC balance after payment
        uint256 merchantBalanceAfter = usdc.balanceOf(MERCHANT_ADDR);

        // Verify that pending payment is cleared
        assertEq(pendingPaymentAfter, 0);

        // Verify that merchant received the payment
        assertEq(merchantBalanceAfter, merchantBalanceBefore + pendingPaymentBefore);
    }

    function testEligibilityCheck() public {
        // Setup: Register merchant and list item
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.prank(MERCHANT_ADDR);
        uint256 itemId = merchant.listItem(
            "Test Item",
            "A test item for sale",
            ITEM_PRICE,
            0 // Set required ySYLD balance to 0 for testing
        );

        // User should be eligible with 0 requirement
        bool eligible = merchant.isEligibleForPurchase(USER, itemId);
        assertTrue(eligible);
    }

    function testPlatformFeeCollection() public {
        // Setup: Register merchant, list item, and make a purchase
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.prank(MERCHANT_ADDR);
        uint256 itemId = merchant.listItem("Test Item", "A test item for sale", ITEM_PRICE, 0);

        vm.prank(USER);
        merchant.purchaseItem(itemId);

        // Calculate expected platform fee
        uint256 expectedFee = ITEM_PRICE * 2 / 100; // 2% of item price

        // Owner collects platform fees
        vm.prank(OWNER);
        merchant.collectPlatformFees();

        // Verify platform fees are reset
        assertEq(merchant.platformFees(), 0);
    }

    function testUpdateMerchant() public {
        // Register merchant
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        // Update merchant info
        vm.prank(MERCHANT_ADDR);
        merchant.updateMerchant("Updated Merchant", "Updated description");

        // Verify updated info
        (bool isRegistered, string memory name, string memory description, , ) = merchant.getMerchantInfo(MERCHANT_ADDR);

        assertTrue(isRegistered);
        assertEq(name, "Updated Merchant");
        assertEq(description, "Updated description");
    }

    function testUpdateItem() public {
        // Register merchant and list item
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.prank(MERCHANT_ADDR);
        uint256 itemId = merchant.listItem("Test Item", "A test item for sale", ITEM_PRICE, 70e6);

        // Update item
        vm.prank(MERCHANT_ADDR);
        merchant.updateItem(itemId, ITEM_PRICE * 2, 100e6, true);

        // Verify updated item
        (
            ,
            ,
            ,
            ,
            uint256 price,
            uint256 requiredYSYLD,
            bool isActive
        ) = merchant.getItemInfo(itemId);

        assertEq(price, ITEM_PRICE * 2);
        assertEq(requiredYSYLD, 100e6);
        assertTrue(isActive);
    }

    function testRevertWhenNonMerchantListsItem() public {
        vm.prank(USER);
        vm.expectRevert("Not registered");
        merchant.listItem("Test Item", "A test item for sale", ITEM_PRICE, 70e6);
    }

    function testRevertWhenInsufficientYSYLD() public {
        // Register merchant and list item
        vm.prank(MERCHANT_ADDR);
        merchant.registerMerchant("Test Merchant", "A test merchant for the marketplace");

        vm.prank(MERCHANT_ADDR);
        uint256 itemId = merchant.listItem("Test Item", "A test item for sale", ITEM_PRICE, 70e6);

        // User tries to purchase without enough ySYLD
        vm.prank(USER);
        vm.expectRevert("Insufficient ySYLD balance");
        merchant.purchaseItem(itemId);
    }

    function testRevertWhenNonOwnerPaysMerchant() public {
        vm.prank(USER);
        vm.expectRevert();
        merchant.payMerchant(MERCHANT_ADDR);
    }
}
