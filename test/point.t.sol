// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Points.sol";
import "../contracts/interfaces/IPoint.sol";
import "./res.t.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RestaurantLoyaltySystemTest is RestaurantTest {
    RestaurantLoyaltySystem public loyalty;
    RestaurantLoyaltySystem public loyaltyImplementation;
    
    function setUp() public {
        
    //     // Deploy contract
        vm.startPrank(Deployer);
        loyalty = new RestaurantLoyaltySystem();
        loyaltyImplementation = new RestaurantLoyaltySystem();
        ERC1967Proxy loyaltyProxy = new ERC1967Proxy(
            address(loyaltyImplementation),
            abi.encodeWithSignature("initialize()")
        );
        loyalty = RestaurantLoyaltySystem(address(loyaltyProxy));
        loyalty.setManagementSC(address(MANAGEMENT));

        vm.stopPrank();
    }
    
    // ============ TEST MEMBER REGISTRATION ============
    
    function testMemberRegistration() public {
        vm.startPrank(customer1);
                
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        (
            string memory memberId,
            uint256 totalPoints,
            uint256 lifetimePoints,
            uint256 totalSpent,
            Tier tier,
            bool isActive,
            bool isLocked,
        ) = loyalty.getMember(customer1);
        
        assertEq(memberId, "CUST0001");
        assertEq(totalPoints, 0);
        assertEq(lifetimePoints, 0);
        assertEq(totalSpent, 0);
        assertTrue(uint8(tier) == 0); // Tier.None
        assertTrue(isActive);
        assertFalse(isLocked);
        
        vm.stopPrank();
    }
    
    function testMemberRegistrationWithInvalidIdLength() public {
        vm.startPrank(customer1);
        
        // Too short
        vm.expectRevert("Invalid member ID length");
        loyalty.registerMember("CUST01", "0123456789", "Nguyen Van A");
        
        // Too long
        vm.expectRevert("Invalid member ID length");
        loyalty.registerMember("CUST0001234567", "0123456789", "Nguyen Van A");
        
        vm.stopPrank();
    }
    
    function testCannotRegisterTwice() public {
        vm.startPrank(customer1);
        
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.expectRevert("Already registered");
        loyalty.registerMember("CUST0002", "0123456789", "Nguyen Van A");
        
        vm.stopPrank();
    }
    
    function testCannotUseDuplicateMemberId() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(customer2);
        vm.expectRevert("Member ID already exists");
        loyalty.registerMember("CUST0001", "0987654321", "Tran Thi B");
    }
    
    // ============ TEST EARN POINTS ============
    
    function testEarnPointsBasic() public {
        // Register customer
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        // Staff helps customer earn points
        // vm.startPrank(customer1);
        
        uint256 amount = 100000; // 100k VND
        uint256 expectedPoints = amount / 10000; // = 10 points (exchangeRate = 10000)
                
        loyalty.earnPoints(customer1, amount, "INV001");
        
        (
            ,
            uint256 totalPoints,
            uint256 lifetimePoints,
            uint256 totalSpent,
            ,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(totalPoints, expectedPoints);
        assertEq(lifetimePoints, expectedPoints);
        assertEq(totalSpent, amount);
        
        vm.stopPrank();
    }
    
    function testEarnPointsWithTierMultiplier() public {
        // Register and reach Silver tier
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        // Earn enough to reach Silver (1000 points)
        vm.startPrank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV001"); // 1000 points base
        
        // Check tier upgraded to Silver
        (,,,, Tier tier,,,) = loyalty.getMember(customer1);
        assertEq(uint8(tier), 1); // Tier.Silver
        
        // Now earn more points with Silver multiplier (1.2x)
        uint256 amount = 100000; // 100k VND
        uint256 basePoints = amount / 10000; // 10 points
        uint256 expectedPoints = (basePoints * 120) / 100; // 12 points with 1.2x
        
        loyalty.earnPoints(customer1, amount, "INV002");
        
        (
            ,
            uint256 totalPoints,
            uint256 lifetimePoints,
            ,,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(totalPoints, 1000 + expectedPoints);
        assertEq(lifetimePoints, 1000 + expectedPoints);
        
        vm.stopPrank();
    }
    
    function testCannotEarnPointsWithDuplicateInvoice() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(staff1);
        
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        vm.expectRevert("Invoice already processed");
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        vm.stopPrank();
    }
    
    function testCannotEarnPointsForLockedMember() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        // Admin locks the member
        vm.prank(admin);
        loyalty.lockMember(customer1, "Suspicious activity");
        
        // Staff tries to earn points
        vm.prank(staff1);
        vm.expectRevert("Account is locked");
        loyalty.earnPoints(customer1, 100000, "INV001");
    }
    
    // ============ TEST TIER SYSTEM ============
    
    function testTierUpgrade() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(staff1);
        
        // Start at None tier
        (,,,, Tier tier,,,) = loyalty.getMember(customer1);
        assertEq(uint8(tier), 0); // Tier.None
                
        loyalty.earnPoints(customer1, 10000000, "INV001"); // 1000 points
        
        (,,,, tier,,,) = loyalty.getMember(customer1);
        assertEq(uint8(tier), 1); // Tier.Silver
        
        // Earn more for Gold (3000 points total)
        loyalty.earnPoints(customer1, 20000000, "INV002"); // 2000 more points (with 1.2x = 2400)
        
        (,,,, tier,,,) = loyalty.getMember(customer1);
        assertEq(uint8(tier), 2); // Tier.Gold
        
        vm.stopPrank();
    }
    
    // ============ TEST EVENTS & CAMPAIGNS ============
    
    function testCreateEvent() public {
        vm.startPrank(admin);
        
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 7 days;
        
        uint256 eventId = loyalty.createEvent(
            "Tet 2025",
            startTime,
            endTime,
            200, // 2x multiplier
            Tier.Silver,
            5000, // max 5000 points per invoice
            20000, // max 20000 points per member
            "Lunar New Year Promotion"
        );
        
        assertEq(eventId, 1);
        
        (
            string memory name,
            uint256 start,
            uint256 end,
            uint256 multiplier,
            Tier minTier,
            bool isActive
        ) = loyalty.getEvent(eventId);
        
        assertEq(name, "Tet 2025");
        assertEq(start, startTime);
        assertEq(end, endTime);
        assertEq(multiplier, 200);
        assertEq(uint8(minTier), 1); // Tier.Silver
        assertTrue(isActive);
        
        vm.stopPrank();
    }
    
    function testEarnPointsWithEvent() public {
        // Setup: Register customer and reach Silver tier
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV001"); // Reach Silver
        
        // Create event
        vm.prank(admin);
        loyalty.createEvent(
            "Tet 2025",
            block.timestamp,
            block.timestamp + 7 days,
            200, // 2x
            Tier.Silver,
            0, // no max per invoice
            0, // no max per member
            "Lunar New Year"
        );
        
        // Earn points during event
        vm.prank(staff1);
        uint256 amount = 100000; // 100k VND
        uint256 basePoints = amount / 10000; // 10 points
        uint256 tierPoints = (basePoints * 120) / 100; // 12 points (Silver 1.2x)
        uint256 eventPoints = (tierPoints * 200) / 100; // 24 points (Event 2x)
        
        loyalty.earnPoints(customer1, amount, "INV002");
        
        (
            ,
            uint256 totalPoints,
            ,,,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(totalPoints, 1000 + eventPoints);
    }
    
    function testEventMaxPointsPerInvoice() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV001"); // Silver tier
        
        // Create event with max 100 points per invoice
        vm.prank(admin);
        loyalty.createEvent(
            "Limited Event",
            block.timestamp,
            block.timestamp + 7 days,
            300, // 3x
            Tier.Silver,
            100, // max 100 points per invoice
            0,
            "Limited promotion"
        );
        
        // Try to earn more but should be capped at 100
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV002"); // Would be ~3600 points but capped at 100
        
        (
            ,
            uint256 totalPoints,
            ,,,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(totalPoints, 1000 + 100); // Previous 1000 + capped 100
    }
    
    // ============ TEST REWARDS ============
    
    function testCreateReward() public {
        vm.startPrank(admin);
                
        uint256 rewardId = loyalty.createReward(
            "Free Lunch Combo",
            1000,
            Tier.Gold,
            50,
            "Free combo meal"
        );
        
        assertEq(rewardId, 1);
        
        (
            string memory name,
            uint256 pointsCost,
            Tier minTier,
            uint256 quantity,
            bool isActive
        ) = loyalty.getReward(rewardId);
        
        assertEq(name, "Free Lunch Combo");
        assertEq(pointsCost, 1000);
        assertEq(uint8(minTier), 2); // Tier.Gold
        assertEq(quantity, 50);
        assertTrue(isActive);
        
        vm.stopPrank();
    }
    
    function testRedeemPoints() public {
        // Setup customer with points
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 20000000, "INV001"); // ~2000 points
        
        // Create reward
        vm.prank(admin);
        uint256 rewardId = loyalty.createReward(
            "Coffee Cup",
            500,
            Tier.None,
            100,
            "Branded coffee cup"
        );
        
        // Redeem
        vm.startPrank(customer1);
        
        uint256 pointsBefore;
        (
            ,
            pointsBefore,
            ,,,,,
        ) = loyalty.getMember(customer1);
                
        loyalty.redeemPoints(rewardId);
        
        uint256 pointsAfter;
        (
            ,
            pointsAfter,
            ,,,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(pointsAfter, pointsBefore - 500);
        
        // Check reward quantity decreased
        (,, , uint256 quantity,) = loyalty.getReward(rewardId);
        assertEq(quantity, 99);
        
        vm.stopPrank();
    }
    
    function testCannotRedeemWithInsufficientPoints() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV001"); // 100 points
        
        vm.prank(admin);
        uint256 rewardId = loyalty.createReward("Expensive Gift", 1000, Tier.None, 10, "Gift");
        
        vm.prank(customer1);
        vm.expectRevert("Insufficient points");
        loyalty.redeemPoints(rewardId);
    }
    
    function testCannotRedeemWithoutRequiredTier() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 5000000, "INV001"); // 500 points, still None tier
        
        vm.prank(admin);
        uint256 rewardId = loyalty.createReward("Gold Gift", 300, Tier.Gold, 10, "Gift");
        
        vm.prank(customer1);
        vm.expectRevert("Tier requirement not met");
        loyalty.redeemPoints(rewardId);
    }
    
    // ============ TEST MANUAL REQUESTS ============
    
    function testCreateManualRequest() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(staff1);
                
        uint256 requestId = loyalty.createManualRequest(
            customer1,
            "INV001",
            100000,
            "Customer forgot to scan QR"
        );
        
        assertEq(requestId, 1);
        
        (
            address member,
            string memory invoiceId,
            uint256 amount,
            uint256 pointsToEarn,
            address requestedBy,
            RequestStatus status,
            string memory note
        ) = loyalty.getManualRequest(requestId);
        
        assertEq(member, customer1);
        assertEq(invoiceId, "INV001");
        assertEq(amount, 100000);
        assertEq(pointsToEarn, 10);
        assertEq(requestedBy, staff1);
        assertEq(uint8(status), 0); // Pending
        assertEq(note, "Customer forgot to scan QR");
        
        vm.stopPrank();
    }
    
    function testStaffDailyRequestLimit() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(staff1);
        
        // Create 50 requests (the limit)
        for (uint256 i = 1; i <= 50; i++) {
            string memory invoiceId = string(abi.encodePacked("INV", vm.toString(i)));
            loyalty.createManualRequest(customer1, invoiceId, 100000, "Test");
        }
        
        // 51st should fail
        vm.expectRevert("Daily request limit reached");
        loyalty.createManualRequest(customer1, "INV051", 100000, "Test");
        
        vm.stopPrank();
        
        // Next day, limit resets
        vm.warp(block.timestamp + 1 days);
        
        vm.prank(staff1);
        uint256 requestId = loyalty.createManualRequest(customer1, "INV052", 100000, "Test");
        assertEq(requestId, 51);
    }
    
    function testApproveManualRequest() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        uint256 requestId = loyalty.createManualRequest(customer1, "INV001", 100000, "Forgot to scan");
        
        vm.startPrank(admin);
        
        loyalty.approveManualRequest(requestId);
        
        // Check points were added
        (
            ,
            uint256 totalPoints,
            ,,,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(totalPoints, 10); // 100000 / 10000 = 10 points
        
        // Check request status
        (,,,,, RequestStatus status,) = loyalty.getManualRequest(requestId);
        assertEq(uint8(status), 1); // Approved
        
        vm.stopPrank();
    }
    
    function testRejectManualRequest() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        uint256 requestId = loyalty.createManualRequest(customer1, "INV001", 100000, "Forgot to scan");
        
        vm.startPrank(admin);
                
        loyalty.rejectManualRequest(requestId, "Invalid invoice");
        
        // Check points were NOT added
        (
            ,
            uint256 totalPoints,
            ,,,,,
        ) = loyalty.getMember(customer1);
        
        assertEq(totalPoints, 0);
        
        // Check request status
        (,,,,, RequestStatus status,) = loyalty.getManualRequest(requestId);
        assertEq(uint8(status), 2); // Rejected
        
        vm.stopPrank();
    }
    
    function testBatchApproveRequests() public {
        // Register multiple customers
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer 1");
        
        vm.prank(customer2);
        loyalty.registerMember("CUST0002", "0987654321", "Customer 2");
        address customer3 = address(0x111111);
        vm.prank(customer3);
        loyalty.registerMember("CUST0003", "0111222333", "Customer 3");
        
        // Staff creates multiple requests
        vm.startPrank(staff1);
        loyalty.createManualRequest(customer1, "INV001", 100000, "Request 1");
        loyalty.createManualRequest(customer2, "INV002", 200000, "Request 2");
        loyalty.createManualRequest(customer3, "INV003", 150000, "Request 3");
        vm.stopPrank();
        
        // Admin batch approves
        vm.prank(admin);
        uint256[] memory requestIds = new uint256[](3);
        requestIds[0] = 1;
        requestIds[1] = 2;
        requestIds[2] = 3;
        
        loyalty.batchApproveRequests(requestIds);
        
        // Check all were approved and points added
        (, uint256 points1,,,,,,) = loyalty.getMember(customer1);
        (, uint256 points2,,,,,,) = loyalty.getMember(customer2);
        (, uint256 points3,,,,,,) = loyalty.getMember(customer3);
        
        assertEq(points1, 10);  // 100k / 10k
        assertEq(points2, 20);  // 200k / 10k
        assertEq(points3, 15);  // 150k / 10k
    }
    
    // ============ TEST ADMIN FUNCTIONS ============
    
    function testAdjustPointsManual() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV001"); // 100 points
        
        vm.startPrank(admin);
        
        // Add points manually
        loyalty.adjustPoints(customer1, 50, "Compensation for service issue");
        
        (, uint256 points1,,,,,,) = loyalty.getMember(customer1);
        assertEq(points1, 150);
        
        // Subtract points manually
        loyalty.adjustPoints(customer1, -30, "Correction for duplicate entry");
        
        (, uint256 points2,,,,,,) = loyalty.getMember(customer1);
        assertEq(points2, 120);
        
        vm.stopPrank();
    }
    
    function testAdjustPointsRequiresReason() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(admin);
        vm.expectRevert("Reason required");
        loyalty.adjustPoints(customer1, 50, "");
    }
    
    function testRefundPoints() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 500000, "INV001"); // 50 points
        
        (, uint256 pointsBefore,,,,,,) = loyalty.getMember(customer1);
        assertEq(pointsBefore, 50);
        
        vm.startPrank(admin);
                
        loyalty.refundPoints(customer1, "INV001", "Customer cancelled order");
        
        (, uint256 pointsAfter,,,,,,) = loyalty.getMember(customer1);
        assertEq(pointsAfter, 0);
        
        // Invoice should be unmarked as processed
        assertFalse(loyalty.isInvoiceProcessed("INV001"));
        
        vm.stopPrank();
    }
    
    function testLockAndUnlockMember() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(admin);
        
        // Lock member
        loyalty.lockMember(customer1, "Suspicious activity");
        
        (,,,,,, bool isLocked,) = loyalty.getMember(customer1);
        assertTrue(isLocked);
        
        // Unlock member
        
        loyalty.unlockMember(customer1);
        
        (,,,,,, isLocked,) = loyalty.getMember(customer1);
        assertFalse(isLocked);
        
        vm.stopPrank();
    }
    
    function testIssuePoints() public {
        vm.startPrank(admin);
        
        uint256 issuanceBefore = loyalty.totalPointsIssued();
        
        loyalty.issuePoints(100000, "New year bonus pool");
        
        // Note: issuePoints only creates a record, doesn't automatically add to totalPointsIssued
        // That happens when points are actually earned by members
        
        vm.stopPrank();
    }
    
    function testExpirePoints() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV001"); // 100 points
        
        // Fast forward past expiry period (365 days)
        vm.warp(block.timestamp + 366 days);
        
        vm.startPrank(admin);
                
        loyalty.expirePoints(customer1);
        
        (, uint256 points,,,Tier tier,,,) = loyalty.getMember(customer1);
        assertEq(points, 0);
        assertEq(uint8(tier), 0); // Back to None
        
        vm.stopPrank();
    }
        
    // ============ TEST STAFF PERMISSIONS ============
    
    function testStaffCanEarnPoints() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        (, uint256 points,,,,,,) = loyalty.getMember(customer1);
        assertEq(points, 10);
    }
    
    function testStaffCanCreateManualRequest() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        uint256 requestId = loyalty.createManualRequest(customer1, "INV001", 100000, "Test");
        assertEq(requestId, 1);
    }
    
    function testStaffCanRedeemPointsForCustomer() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV001"); // 100 points
        
        vm.prank(staff2);
        loyalty.redeemPointsForCustomer(customer1, 50, "Redeemed at counter");
        
        (, uint256 points,,,,,,) = loyalty.getMember(customer1);
        assertEq(points, 50);
    }
    
    function testStaffCannotApproveRequests() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        uint256 requestId = loyalty.createManualRequest(customer1, "INV001", 100000, "Test");
        
        address staff3 = address(0x2222);
        vm.prank(staff3);
        vm.expectRevert("Only admin");
        loyalty.approveManualRequest(requestId);
    }
    
    function testStaffCannotLockMembers() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        vm.expectRevert("Only admin");
        loyalty.lockMember(customer1, "Test");
    }
    
    function testStaffCannotCreateEvents() public {
        vm.prank(staff1);
        vm.expectRevert("Only admin");
        loyalty.createEvent(
            "Test Event",
            block.timestamp,
            block.timestamp + 7 days,
            200,
            Tier.None,
            0,
            0,
            "Test"
        );
    }
    
    // ============ TEST VIEW FUNCTIONS ============
    
    function testGetMemberByMemberId() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        (
            address wallet,
            uint256 totalPoints,
            uint256 lifetimePoints,
            Tier tier,
            bool isActive,
            bool isLocked
        ) = loyalty.getMemberByMemberId("CUST0001");
        
        assertEq(wallet, customer1);
        assertEq(totalPoints, 0);
        assertEq(lifetimePoints, 0);
        assertEq(uint8(tier), 0);
        assertTrue(isActive);
        assertFalse(isLocked);
    }
    
    function testGetMemberTransactions() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        loyalty.earnPoints(customer1, 200000, "INV002");
        loyalty.earnPoints(customer1, 150000, "INV003");
        vm.stopPrank();
        
        uint256[] memory txIds = loyalty.getMemberTransactions(customer1);
        assertEq(txIds.length, 3);
        assertEq(txIds[0], 1);
        assertEq(txIds[1], 2);
        assertEq(txIds[2], 3);
    }
    
    function testGetTransaction() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        (
            address member,
            TransactionType txType,
            int256 points,
            uint256 amount,
            string memory invoiceId,
            uint256 timestamp,
            string memory note
        ) = loyalty.getTransaction(1);
        
        assertEq(member, customer1);
        assertEq(uint8(txType), 0); // TransactionType.Earn
        assertEq(points, 10);
        assertEq(amount, 100000);
        assertEq(invoiceId, "INV001");
        assertGt(timestamp, 0);
    }
    
    function testGetActiveEvents() public {
        vm.startPrank(admin);
        uint currentTime = 1760515357;
        vm.warp(currentTime);
        // Create active event
        loyalty.createEvent(
            "Active Event 1",
            currentTime,
            currentTime + 7 days,
            200,
            Tier.None,
            0,
            0,
            "Active"
        );
        
        // Create future event (not yet started)
        loyalty.createEvent(
            "Future Event",
            currentTime + 10 days,
            currentTime + 20 days,
            200,
            Tier.None,
            0,
            0,
            "Future"
        );
        
        // Create another active event
        loyalty.createEvent(
            "Active Event 2",
            currentTime - 1 days,
            currentTime + 5 days,
            150,
            Tier.None,
            0,
            0,
            "Active"
        );
        
        vm.stopPrank();
        
        uint256[] memory activeEvents = loyalty.getActiveEvents();
        assertEq(activeEvents.length, 2);
        assertEq(activeEvents[0], 1);
        assertEq(activeEvents[1], 3);
    }
    
    function testGetAvailableRewards() public {
        vm.startPrank(admin);
        
        loyalty.createReward("Reward 1", 100, Tier.None, 10, "Available");
        loyalty.createReward("Reward 2", 200, Tier.None, 0, "Out of stock");
        loyalty.createReward("Reward 3", 300, Tier.None, 5, "Available");
        
        uint256 rewardId = loyalty.createReward("Reward 4", 400, Tier.None, 20, "Will be inactive");
        loyalty.toggleReward(rewardId, false); // Deactivate
        
        vm.stopPrank();
        
        uint256[] memory available = loyalty.getAvailableRewards();
        assertEq(available.length, 2);
        assertEq(available[0], 1);
        assertEq(available[1], 3);
    }
    
    function testGetPendingRequests() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.startPrank(staff1);
        loyalty.createManualRequest(customer1, "INV001", 100000, "Request 1");
        loyalty.createManualRequest(customer1, "INV002", 200000, "Request 2");
        loyalty.createManualRequest(customer1, "INV003", 150000, "Request 3");
        vm.stopPrank();
        
        uint256[] memory pending = loyalty.getPendingRequests();
        assertEq(pending.length, 3);
        
        // Approve one
        vm.prank(admin);
        loyalty.approveManualRequest(1);
        
        pending = loyalty.getPendingRequests();
        assertEq(pending.length, 2);
        assertEq(pending[0], 2);
        assertEq(pending[1], 3);
    }
    
    function testCalculatePointsFromAmount() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        // Without tier (None)
        uint256 points1 = loyalty.calculatePointsFromAmount(100000, customer1);
        assertEq(points1, 10); // 100k / 10k = 10
        
        // Reach Silver tier
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV001");
        
        // With Silver tier (1.2x)
        uint256 points2 = loyalty.calculatePointsFromAmount(100000, customer1);
        assertEq(points2, 12); // 10 * 1.2 = 12
        
        // Create event with 2x multiplier
        vm.prank(admin);
        loyalty.createEvent(
            "Double Points",
            block.timestamp,
            block.timestamp + 7 days,
            200,
            Tier.Silver,
            0,
            0,
            "Event"
        );
        
        // With event (1.2x tier * 2x event = 2.4x)
        uint256 points3 = loyalty.calculatePointsFromAmount(100000, customer1);
        assertEq(points3, 24); // 10 * 1.2 * 2 = 24
    }
    
    function testCanRedeemReward() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        vm.prank(admin);
        uint256 rewardId = loyalty.createReward(
            "Gold Gift",
            500,
            Tier.Gold,
            10,
            "Exclusive"
        );
        
        // Customer doesn't have enough points or tier
        bool canRedeem1 = loyalty.canRedeemReward(customer1, rewardId);
        assertFalse(canRedeem1);
        
        // Give points but still no tier
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 6000000, "INV001"); // 600 points
        
        bool canRedeem2 = loyalty.canRedeemReward(customer1, rewardId);
        assertFalse(canRedeem2); // Has points but not Gold tier
        
        // Reach Gold tier
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 24000000, "INV002"); // More points to reach Gold
        
        bool canRedeem3 = loyalty.canRedeemReward(customer1, rewardId);
        assertTrue(canRedeem3); // Now has both points and tier
    }
    
    function testGetTierConfig() public {
        (
            uint256 pointsRequired,
            uint256 multiplier,
            uint256 validityPeriod
        ) = loyalty.getTierConfig(Tier.Gold);
        
        assertEq(pointsRequired, 3000);
        assertEq(multiplier, 150); // 1.5x
        assertEq(validityPeriod, 365 days);
    }
    
    function testGetSystemStats() public {
        // Register some members
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer 1");
        
        vm.prank(customer2);
        loyalty.registerMember("CUST0002", "0987654321", "Customer 2");
        
        // Earn some points
        vm.startPrank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        loyalty.earnPoints(customer2, 200000, "INV002");
        vm.stopPrank();
        
        // Create reward and redeem
        vm.prank(admin);
        uint256 rewardId = loyalty.createReward("Gift", 10, Tier.None, 5, "Test");
        
        vm.prank(customer1);
        loyalty.redeemPoints(rewardId);
        
        (
            uint256 totalIssued,
            uint256 totalRedeemed,
            ,
            uint256 totalTransactions,
            ,
        ) = loyalty.getSystemStats();
        
        assertEq(totalIssued, 30); // 10 + 20 from earnPoints
        assertEq(totalRedeemed, 10);
        assertEq(totalTransactions, 3); // 2 earn + 1 redeem
    }
    
    // ============ TEST SYSTEM SETTINGS ============
    
    function testUpdateExchangeRate() public {
        uint256 oldRate = loyalty.exchangeRate();
        assertEq(oldRate, 10000);
        
        vm.prank(admin);
        loyalty.updateExchangeRate(20000);
        
        uint256 newRate = loyalty.exchangeRate();
        assertEq(newRate, 20000);
        
        // Test earning with new rate
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        (, uint256 points,,,,,,) = loyalty.getMember(customer1);
        assertEq(points, 5); // 100k / 20k = 5 points
    }
    
    function testUpdatePointExpiryPeriod() public {
        vm.prank(admin);
        loyalty.updatePointExpiryPeriod(180 days);
        
        assertEq(loyalty.pointExpiryPeriod(), 180 days);
    }
    
    function testUpdateSessionDuration() public {
        vm.prank(admin);
        loyalty.updateSessionDuration(60 days);
        
        assertEq(loyalty.sessionDuration(), 60 days);
    }
    
    function testUpdateTierConfig() public {
        vm.prank(admin);
        loyalty.updateTierConfig(
            Tier.Silver,
            2000,  // New points requirement
            130,   // New multiplier (1.3x)
            90 days // New validity period
        );
        
        (
            uint256 pointsRequired,
            uint256 multiplier,
            uint256 validityPeriod
        ) = loyalty.getTierConfig(Tier.Silver);
        
        assertEq(pointsRequired, 2000);
        assertEq(multiplier, 130);
        assertEq(validityPeriod, 90 days);
    }
    
    function testToggleEvent() public {
        vm.startPrank(admin);
        
        uint256 eventId = loyalty.createEvent(
            "Test Event",
            block.timestamp,
            block.timestamp + 7 days,
            200,
            Tier.None,
            0,
            0,
            "Test"
        );
        
        (,,,,, bool isActive1) = loyalty.getEvent(eventId);
        assertTrue(isActive1);
        
        loyalty.toggleEvent(eventId, false);
        
        (,,,,, bool isActive2) = loyalty.getEvent(eventId);
        assertFalse(isActive2);
        
        loyalty.toggleEvent(eventId, true);
        
        (,,,,, bool isActive3) = loyalty.getEvent(eventId);
        assertTrue(isActive3);
        
        vm.stopPrank();
    }
    
    function testToggleReward() public {
        vm.startPrank(admin);
        
        uint256 rewardId = loyalty.createReward("Test", 100, Tier.None, 10, "Test");
        
        (,,,, bool isActive1) = loyalty.getReward(rewardId);
        assertTrue(isActive1);
        
        loyalty.toggleReward(rewardId, false);
        
        (,,,, bool isActive2) = loyalty.getReward(rewardId);
        assertFalse(isActive2);
        
        vm.stopPrank();
    }
    
    function testUpdateRewardQuantity() public {
        vm.startPrank(admin);
        
        uint256 rewardId = loyalty.createReward("Test", 100, Tier.None, 10, "Test");
        
        (,,, uint256 quantity1,) = loyalty.getReward(rewardId);
        assertEq(quantity1, 10);
        
        loyalty.updateRewardQuantity(rewardId, 50);
        
        (,,, uint256 quantity2,) = loyalty.getReward(rewardId);
        assertEq(quantity2, 50);
        
        vm.stopPrank();
    }
    
    // ============ TEST EDGE CASES ============
    
    function testCannotEarnZeroPoints() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        vm.prank(staff1);
        vm.expectRevert("Invalid amount");
        loyalty.earnPoints(customer1, 0, "INV001");
    }
    
    function testCannotRedeemFromInactiveReward() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV001");
        
        vm.startPrank(admin);
        uint256 rewardId = loyalty.createReward("Test", 50, Tier.None, 10, "Test");
        loyalty.toggleReward(rewardId, false);
        vm.stopPrank();
        
        vm.prank(customer1);
        vm.expectRevert("Reward not active");
        loyalty.redeemPoints(rewardId);
    }
    
    function testCannotRedeemOutOfStockReward() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV001");
        
        vm.startPrank(admin);
        uint256 rewardId = loyalty.createReward("Test", 50, Tier.None, 0, "Test");
        vm.stopPrank();
        
        vm.prank(customer1);
        vm.expectRevert("Reward out of stock");
        loyalty.redeemPoints(rewardId);
    }
    
    function testCannotSubtractMorePointsThanAvailable() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 500000, "INV001"); // 50 points
        
        vm.prank(admin);
        vm.expectRevert("Insufficient points");
        loyalty.adjustPoints(customer1, -100, "Test");
    }
    
    function testMultipleTierUpgradesInOneTransaction() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        // Earn enough to jump from None to Gold directly
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 30000000, "INV001"); // 3000 points
        
        (,,,, Tier tier,,,) = loyalty.getMember(customer1);
        assertEq(uint8(tier), 2); // Should be Gold
    }
    
    function testInvoiceCanBeReusedAfterRefund() public {
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        assertTrue(loyalty.isInvoiceProcessed("INV001"));
        
        // Refund
        vm.prank(admin);
        loyalty.refundPoints(customer1, "INV001", "Order cancelled");
        
        assertFalse(loyalty.isInvoiceProcessed("INV001"));
        
        // Can use same invoice again
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        (, uint256 points,,,,,,) = loyalty.getMember(customer1);
        assertEq(points, 10);
    }
    
    // ============ TEST FULL USER JOURNEY ============
    
    function testFullUserJourney() public {
        console.log("=== Starting Full User Journey Test ===");
        
        // 1. Customer registers
        console.log("1. Customer registration");
        vm.prank(customer1);
        loyalty.registerMember("CUST0001", "0123456789", "Nguyen Van A");
        
        // 2. Customer makes first purchase (100k VND)
        console.log("2. First purchase - earning points");
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 100000, "INV001");
        
        (, uint256 points1,,,,,,) = loyalty.getMember(customer1);
        console.log("Points after first purchase:", points1);
        assertEq(points1, 10);
        
        // 3. Customer accumulates points to reach Silver
        console.log("3. Accumulating points to Silver tier");
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV002"); // 1000 points
        
        (,,,, Tier tier1,,,) = loyalty.getMember(customer1);
        console.log("Tier after accumulation:", uint8(tier1));
        assertEq(uint8(tier1), 1); // Silver
        
        // 4. Admin creates double points event
        console.log("4. Admin creates double points event");
        vm.prank(admin);
        uint256 eventId = loyalty.createEvent(
            "Tet 2025",
            block.timestamp,
            block.timestamp + 7 days,
            200, // 2x
            Tier.Silver,
            0,
            0,
            "Lunar New Year"
        );
        
        // 5. Customer purchases during event
        console.log("5. Purchase during event");
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 1000000, "INV003"); // Should get (100 * 1.2 * 2) = 240 points
        
        (, uint256 points2,,,,,,) = loyalty.getMember(customer1);
        console.log("Points after event purchase:", points2);
        
        // 6. Customer forgets to scan QR, staff creates manual request
        console.log("6. Manual request created");
        vm.prank(staff2);
        uint256 requestId = loyalty.createManualRequest(customer1, "INV004", 500000, "Customer forgot to scan");
        
        // 7. Admin approves manual request
        console.log("7. Admin approves manual request");
        vm.prank(admin);
        loyalty.approveManualRequest(requestId);
        
        // 8. Admin creates rewards
        console.log("8. Creating rewards");
        vm.startPrank(admin);
        uint256 reward1 = loyalty.createReward("Coffee Cup", 300, Tier.None, 100, "Branded cup");
        uint256 reward2 = loyalty.createReward("Free Lunch", 1000, Tier.Gold, 50, "Combo meal");
        vm.stopPrank();
        
        // 9. Customer redeems points for coffee cup
        console.log("9. Customer redeems coffee cup");
        vm.prank(customer1);
        loyalty.redeemPoints(reward1);
        
        (, uint256 pointsAfterRedeem,,,,,,) = loyalty.getMember(customer1);
        console.log("Points after redemption:", pointsAfterRedeem);
        
        // 10. Customer continues shopping to reach Gold
        console.log("10. Shopping to reach Gold tier");
        vm.prank(staff1);
        loyalty.earnPoints(customer1, 10000000, "INV005");
        
        (,,,, Tier finalTier,,,) = loyalty.getMember(customer1);
        console.log("Final tier:", uint8(finalTier));
        
        // 11. Check transaction history
        console.log("11. Checking transaction history");
        uint256[] memory txIds = loyalty.getMemberTransactions(customer1);
        console.log("Total transactions:", txIds.length);
        assertGt(txIds.length, 5);
        
        console.log("=== Full User Journey Test Completed Successfully ===");
    }
    
    // // ============ TEST GAS OPTIMIZATION ============
    
    // function testGasEarnPoints() public {
    //     vm.prank(customer1);
    //     loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
    //     vm.prank(staff1);
    //     uint256 gasBefore = gasleft();
    //     loyalty.earnPoints(customer1, 100000, "INV001");
    //     uint256 gasUsed = gasBefore - gasleft();
        
    //     console.log("Gas used for earnPoints:", gasUsed);
    //     assertLt(gasUsed, 200000); // Should use less than 200k gas
    // }
    
    // function testGasBatchApprove() public {
    //     vm.prank(customer1);
    //     loyalty.registerMember("CUST0001", "0123456789", "Customer");
        
    //     vm.startPrank(staff1);
    //     for (uint256 i = 1; i <= 10; i++) {
    //         string memory invoiceId = string(abi.encodePacked("INV", vm.toString(i)));
    //         loyalty.createManualRequest(customer1, invoiceId, 100000, "Test");
    //     }
    //     vm.stopPrank();
        
    //     uint256[] memory requestIds = new uint256[](10);
    //     for (uint256 i = 0; i < 10; i++) {
    //         requestIds[i] = i + 1;
    //     }
        
    //     vm.prank(admin);
    //     uint256 gasBefore = gasleft();
    //     loyalty.batchApproveRequests(requestIds);
    //     uint256 gasUsed = gasBefore - gasleft();
        
    //     console.log("Gas used for batch approving 10 requests:", gasUsed);
    // }
}