// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/agent.sol";
import "../contracts/agentIqr.sol";
import "../contracts/enhance.sol";
import "../contracts/interfaces/IAgent.sol";
import "../contracts/loyaltyFactory.sol";
import "../contracts/iqrFactory.sol";
import "../contracts/revenue.sol";
import "../contracts/mtd.sol";
/**
 * @title Agent Management Integration Test
 * @notice Comprehensive integration tests for the Agent Management system
 * @dev Tests full workflow including create, update, delete, pagination, and loyalty operations
 */
contract AgentManagementIntegrationTest is Test {
    // Contracts
    AgentManagement public agentManagementImplementation;
    AgentManagement public agentManagement;
    EnhancedAgentManagement public enhancedImplementation;
    EnhancedAgentManagement public enhanced;
    
    IQRFactory public iqrFactoryImplementation;
    IQRFactory public iqrFactory;
    
    LoyaltyFactory public loyaltyFactoryImplementation;
    LoyaltyFactory public loyaltyFactory;
    
    RevenueManager public revenueManagerImplementation;
    RevenueManager public revenueManager;
    
    MTDToken public mtdTokenImplementation;
    MTDToken public mtdToken;
    
    // Test accounts
    address public superAdmin;
    address public agent1;
    address public agent2;
    address public agent3;
    address public agent4;
    address public customer1;
    address public customer2;
        
    constructor() {
        // Setup accounts
        superAdmin = makeAddr("superAdmin");
        agent1 = makeAddr("agent1");
        agent2 = makeAddr("agent2");
        agent3 = makeAddr("agent3");
        agent4 = makeAddr("agent4");
        customer1 = makeAddr("customer1");
        customer2 = makeAddr("customer2");
        
        // vm.deal(superAdmin, 100 ether);
        
        // Deploy all contracts with proxy pattern
        vm.startPrank(superAdmin);
        
        // 1. Deploy AgentManagement
        agentManagementImplementation = new AgentManagement();
        ERC1967Proxy agentProxy = new ERC1967Proxy(
            address(agentManagementImplementation),
            abi.encodeWithSignature("initialize()")
        );
        agentManagement = AgentManagement(address(agentProxy));
        
        // 2. Deploy IQRFactory
        iqrFactoryImplementation = new IQRFactory();
        ERC1967Proxy iqrProxy = new ERC1967Proxy(
            address(iqrFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        iqrFactory = IQRFactory(address(iqrProxy));
        
        // 3. Deploy LoyaltyFactory
        loyaltyFactoryImplementation = new LoyaltyFactory();
        ERC1967Proxy loyaltyProxy = new ERC1967Proxy(
            address(loyaltyFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        loyaltyFactory = LoyaltyFactory(address(loyaltyProxy));
        
        // 4. Deploy RevenueManager
        revenueManagerImplementation = new RevenueManager();
        ERC1967Proxy revenueProxy = new ERC1967Proxy(
            address(revenueManagerImplementation),
            abi.encodeWithSignature("initialize()")
        );
        revenueManager = RevenueManager(address(revenueProxy));
        
        // 5. Deploy MTDToken
        mtdTokenImplementation = new MTDToken();
        ERC1967Proxy mtdProxy = new ERC1967Proxy(
            address(mtdTokenImplementation),
            abi.encodeWithSignature("initialize(uint256)", 1000000)
        );
        mtdToken = MTDToken(address(mtdProxy));
        
        // 6. Deploy EnhancedAgentManagement (inherits from AgentManagement)
        enhancedImplementation = new EnhancedAgentManagement();
        ERC1967Proxy enhancedProxy = new ERC1967Proxy(
            address(enhancedImplementation),
            abi.encodeWithSignature("initialize()")
        );
        enhanced = EnhancedAgentManagement(address(enhancedProxy));
        
        // Setup admin
        enhanced.setAdmin(superAdmin);
               
        enhanced.setFactoryContracts(
            address(iqrFactory),
            address(loyaltyFactory),
            address(revenueManager),
            address(mtdToken)
        );
        iqrFactory.setEnhancedAgent(address(enhanced));
        iqrFactory.setIQRSC(address(0x11),address(0x22),address(0x33),address(0x44));
        // ✅ QUAN TRỌNG: Transfer ownership của factories cho enhanced contract
        // Vì enhanced contract sẽ gọi createAgentIQR() và cần quyền owner
        iqrFactory.transferOwnership(address(enhanced));
        loyaltyFactory.transferOwnership(address(enhanced));
        revenueManager.transferOwnership(address(enhanced));
        vm.stopPrank();
        
        console.log("=== Setup Complete ===");
        console.log("Super Admin:", superAdmin);
        console.log("AgentManagement:", address(agentManagement));
        console.log("EnhancedAgentManagement:", address(enhanced));
        console.log("IQRFactory:", address(iqrFactory));
        console.log("LoyaltyFactory:", address(loyaltyFactory));
    }
    
    // ========================================================================
    // TEST 1: createAgentWithAnalytics
    // ========================================================================
    
    function test_CreateAgentWithAnalytics_Success() public {
        vm.startBroadcast(superAdmin);
        
        // Prepare data
        string memory storeName = "Store One";
        string memory storeAddress = "123 Main St";
        string memory phone = "0123456789";
        string memory note = "Test store";
        bool[3] memory permissions = [true, true, true]; // All permissions
        string[] memory subLocations = new string[](2);
        subLocations[0] = "Branch A";
        subLocations[1] = "Branch B";
        string[] memory subPhones = new string[](2);
        subPhones[0] = "0111111111";
        subPhones[1] = "0122222222";
                
        // Create agent
        bool success = enhanced.createAgentWithAnalytics(
            agent1,
            storeName,
            storeAddress,
            phone,
            note,
            permissions,
            subLocations,
            subPhones
        );
        
        assertTrue(success, "Agent creation should succeed");
        
        // Verify agent data
        Agent memory agent = enhanced.getAgent(agent1);
        assertEq(agent.walletAddress, agent1);
        assertEq(agent.storeName, storeName);
        assertEq(agent.storeAddress, storeAddress);
        assertEq(agent.phone, phone);
        assertTrue(agent.isActive);
        assertTrue(agent.exists);
        assertTrue(agent.permissions[0]); // IQR
        assertTrue(agent.permissions[1]); // Loyalty
        assertTrue(agent.permissions[2]); // MeOS
        assertEq(agent.subLocations.length, 2);
        
        // Verify analytics
        AgentAnalytics memory analytics = enhanced.getAgentAnalytics(agent1);
        assertEq(analytics.totalOrders, 0);
        assertEq(analytics.totalRevenue, 0);
        assertEq(analytics.performanceScore, 50); // Starting score
        assertEq(analytics.meosLicensesActive, 1);
        
        // Verify contracts were created
        address iqrContract = enhanced.agentIQRContracts(agent1);
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        assertTrue(iqrContract != address(0), "IQR contract should be created");
        assertTrue(loyaltyContract != address(0), "Loyalty contract should be created");
        
        // Verify MeOS license
        MeOSLicense memory license = enhanced.getMeOSLicense(agent1);
        assertTrue(license.isActive);
        assertTrue(bytes(license.licenseKey).length > 0);
        
        vm.stopPrank();
        
        console.log("Test 1 PASSED: createAgentWithAnalytics");
    }
    
    function test_CreateAgentWithAnalytics_MultipleAgents() public {
        vm.startPrank(superAdmin);
        
        // Create multiple agents
        address[] memory agents = new address[](3);
        agents[0] = agent1;
        agents[1] = agent2;
        agents[2] = agent3;
        
        for (uint i = 0; i < agents.length; i++) {
            string memory storeName = string(abi.encodePacked("Store ", vm.toString(i + 1)));
            bool[3] memory permissions = [true, true, false]; // IQR + Loyalty only
            string[] memory subLocations = new string[](1);
            subLocations[0] = "Main Branch";
            string[] memory subPhones = new string[](1);
            subPhones[0] = "0123456789";
            
            bool success = enhanced.createAgentWithAnalytics(
                agents[i],
                storeName,
                "Address",
                "Phone",
                "Note",
                permissions,
                subLocations,
                subPhones
            );
            
            assertTrue(success);
        }
        
        // Verify all agents created
        address[] memory allAgents = enhanced.getAllAgents();
        assertEq(allAgents.length, 3, "Should have 3 agents");
        
        vm.stopPrank();
        
        console.log("Test 1b PASSED: Multiple agents created");
    }
    
    // ========================================================================
    // TEST 2: updateAgent
    // ========================================================================
    
    function test_UpdateAgent_Success() public {
        // First create an agent
        vm.startPrank(superAdmin);
        
        bool[3] memory initialPermissions = [true, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch A";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0111111111";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Old Store Name",
            "Old Address",
            "0123456789",
            "Old Note",
            initialPermissions,
            subLocations,
            subPhones
        );
        
        // Update agent
        string memory newStoreName = "New Store Name";
        string memory newAddress = "New Address";
        string memory newPhone = "9876543210";
        string memory newNote = "Updated Note";
        bool[3] memory newPermissions = [true, true, true]; // Grant all permissions
        
        // Update subLocations
        string[] memory updatedSubLocations = new string[](1);
        updatedSubLocations[0] = "Updated Branch A";
        uint[] memory subLocationIndexes = new uint[](1);
        subLocationIndexes[0] = 0;
        
        // Update subPhones
        string[] memory updatedSubPhones = new string[](1);
        updatedSubPhones[0] = "0999999999";
        uint[] memory subPhoneIndexes = new uint[](1);
        subPhoneIndexes[0] = 0;
        
        enhanced.updateAgent(
            agent1,
            newStoreName,
            newAddress,
            newPhone,
            newNote,
            newPermissions,
            updatedSubLocations,
            updatedSubPhones
        );
        
        // Verify updates
        Agent memory updatedAgent = enhanced.getAgent(agent1);
        assertEq(updatedAgent.storeName, newStoreName);
        assertEq(updatedAgent.storeAddress, newAddress);
        assertEq(updatedAgent.phone, newPhone);
        assertEq(updatedAgent.note, newNote);
        assertTrue(updatedAgent.permissions[0]); // IQR
        assertTrue(updatedAgent.permissions[1]); // Loyalty (newly granted)
        assertTrue(updatedAgent.permissions[2]); // MeOS (newly granted)
        assertEq(updatedAgent.subLocations[0], "Updated Branch A");
        assertEq(updatedAgent.subPhones[0], "0999999999");
        
        // Verify new contracts were created
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        assertTrue(loyaltyContract != address(0), "Loyalty contract should be created");
        
        vm.stopPrank();
        
        console.log("Test 2 PASSED: updateAgent");
    }
    
    // ========================================================================
    // TEST 3: deleteAgent
    // ========================================================================
    
    function test_DeleteAgent_Success() public {
        vm.startPrank(superAdmin);
        
        // Create agent
        bool[3] memory permissions = [true, false, true]; // IQR + MeOS (no loyalty)
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store To Delete",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        // Verify agent exists and is active
        Agent memory agentBefore = enhanced.getAgent(agent1);
        assertTrue(agentBefore.isActive);
        
        // Delete agent
        
        enhanced.deleteAgent(agent1);
        
        // Verify agent is deleted
        Agent memory agentAfter = enhanced.getAgent(agent1);
        assertFalse(agentAfter.isActive, "Agent should be inactive");
        assertTrue(agentAfter.exists, "Agent should still exist in records");
        
        // Verify deleted agents list
        Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
        assertEq(deletedAgents.length, 1, "Should have 1 deleted agent");
        assertEq(deletedAgents[0].walletAddress, agent1);
        
        vm.stopPrank();
        
        console.log("Test 3 PASSED: deleteAgent");
    }
    
    function test_DeleteAgent_WithActiveLoyaltyTokens_ShouldRevert() public {
        vm.startPrank(superAdmin);
        
        // Create agent with loyalty permission
        bool[3] memory permissions = [true, true, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store With Loyalty",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        // Mint some loyalty tokens
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        vm.stopPrank();
        
        vm.prank(agent1);
        AgentLoyalty(loyaltyContract).mint(customer1, 1000 ether, "Initial mint");
        
        // Try to delete agent with active tokens - should revert
        vm.prank(superAdmin);
        vm.expectRevert("HasActiveLoyaltyTokens");
        enhanced.deleteAgent(agent1);
        
        console.log("Test 3b PASSED: Cannot delete agent with active loyalty tokens");
    }
    
    function test_DeleteAgent_AfterFreezingLoyalty_Success() public {
        vm.startPrank(superAdmin);
        
        // Create agent with loyalty
        bool[3] memory permissions = [true, true, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        // Mint tokens
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        vm.stopPrank();
        
        vm.prank(agent1);
        AgentLoyalty(loyaltyContract).mint(customer1, 1000 ether, "Mint");
        
        // Freeze the loyalty contract
        vm.prank(agent1);
        AgentLoyalty(loyaltyContract).freeze();
        
        // Now deletion should succeed
        vm.prank(superAdmin);
        enhanced.deleteAgent(agent1);
        
        Agent memory deletedAgent = enhanced.getAgent(agent1);
        assertFalse(deletedAgent.isActive);
        
        console.log("Test 3c PASSED: Can delete after freezing loyalty");
    }
    
    // ========================================================================
    // TEST 4: getDeletedAgents
    // ========================================================================
    
    function test_GetDeletedAgents_Multiple() public {
        vm.startPrank(superAdmin);
        
        bool[3] memory permissions = [true, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        // Create and delete multiple agents
        address[] memory agents = new address[](3);
        agents[0] = agent1;
        agents[1] = agent2;
        agents[2] = agent3;
        
        for (uint i = 0; i < agents.length; i++) {
            enhanced.createAgentWithAnalytics(
                agents[i],
                string(abi.encodePacked("Store ", vm.toString(i))),
                "Address",
                "Phone",
                "Note",
                permissions,
                subLocations,
                subPhones
            );
            
            enhanced.deleteAgent(agents[i]);
        }
        
        // Get all deleted agents
        Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
        assertEq(deletedAgents.length, 3, "Should have 3 deleted agents");
        
        // Verify all are inactive
        for (uint i = 0; i < deletedAgents.length; i++) {
            assertFalse(deletedAgents[i].isActive);
        }
        
        vm.stopPrank();
        
        console.log("Test 4 PASSED: getDeletedAgents with multiple agents");
    }
    
    // ========================================================================
    // TEST 5: unlockLoyaltyTokens
    // ========================================================================
    
    function test_UnlockLoyaltyTokens_Success() public {
        vm.startPrank(superAdmin);
        
        // Create agent with loyalty
        bool[3] memory permissions = [false, true, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        vm.stopPrank();
        
        // Mint tokens to the loyalty contract itself
        vm.prank(agent1);
        AgentLoyalty(loyaltyContract).mint(loyaltyContract, 5000 , "Locked tokens");
        
        // Freeze to enable unlock
        vm.prank(agent1);
        AgentLoyalty(loyaltyContract).freeze();
        
        uint256 contractBalanceBefore = AgentLoyalty(loyaltyContract).balanceOf(loyaltyContract);
        assertEq(contractBalanceBefore, 5000 );
        
        // Unlock tokens
        vm.startBroadcast(superAdmin);
        
        uint256 unlockedAmount = enhanced.unlockLoyaltyTokens(agent1);
        
        assertEq(unlockedAmount, 5000 , "Should unlock all tokens");
        
        // Verify tokens moved to agent
        uint256 agentBalance = AgentLoyalty(loyaltyContract).balanceOf(agent1);
        assertEq(agentBalance, 5000 , "Agent should receive unlocked tokens");
        
        uint256 contractBalanceAfter = AgentLoyalty(loyaltyContract).balanceOf(loyaltyContract);
        assertEq(contractBalanceAfter, 0, "Contract balance should be 0");
        
        console.log("Test 5 PASSED: unlockLoyaltyTokens");
        // GetByteCode();
    }
    
    function test_MigrateLoyaltyTokens_Success() public {
        vm.startPrank(superAdmin);
        
        bool[3] memory permissions = [false, true, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        // Create old agent
        enhanced.createAgentWithAnalytics(
            agent1,
            "Old Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        // Create new agent
        enhanced.createAgentWithAnalytics(
            agent2,
            "New Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        address oldLoyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        address newLoyaltyContract = enhanced.agentLoyaltyContracts(agent2);
        
        vm.stopPrank();
        
        // Mint tokens in old contract
        vm.prank(agent1);
        AgentLoyalty(oldLoyaltyContract).mint(customer1, 10000 ether, "Old tokens");
        
        uint256 oldSupply = AgentLoyalty(oldLoyaltyContract).totalSupply();
        assertEq(oldSupply, 10000 ether);
        
        // Migrate tokens
        vm.prank(superAdmin);
        
        uint256 migratedAmount = enhanced.migrateLoyaltyTokens(agent1, agent2);
        
        assertEq(migratedAmount, oldSupply, "Should return migrated amount");
        
        // Verify old contract is frozen and in redeem-only mode
        assertTrue(AgentLoyalty(oldLoyaltyContract).isFrozen());
        assertTrue(AgentLoyalty(oldLoyaltyContract).isRedeemOnly());
        assertTrue(AgentLoyalty(oldLoyaltyContract).isMigrated());
        
        console.log("Test 6 PASSED: migrateLoyaltyTokens");
    }
    
    // ========================================================================
    // TEST 7: getAgentsInfoPaginatedWithPermissions
    // ========================================================================
    
    function test_GetAgentsInfoPaginatedWithPermissions_Success() public {
        uint currentTime = 1760089361;//16h43 ngay10/10/2025
        vm.warp(currentTime); 
        vm.startPrank(superAdmin);
        
        // Create agents with different permissions
        bool[3] memory allPermissions = [true, true, true];
        bool[3] memory iqrOnly = [true, false, false];
        bool[3] memory loyaltyOnly = [false, true, false];
        bool[3] memory noFilter = [false, false, false];

        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        // Agent 1: All permissions
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store 1",
            "Address 1",
            "Phone",
            "Note",
            allPermissions,
            subLocations,
            subPhones
        );
        
        vm.warp(currentTime + 1 seconds);
        
        // Agent 2: IQR only
        enhanced.createAgentWithAnalytics(
            agent2,
            "Store 2",
            "Address 2",
            "Phone",
            "Note",
            iqrOnly,
            subLocations,
            subPhones
        );
        
        vm.warp(currentTime + 2 seconds);
        
        // Agent 3: Loyalty only
        enhanced.createAgentWithAnalytics(
            agent3,
            "Store 3",
            "Address 3",
            "Phone",
            "Note",
            loyaltyOnly,
            subLocations,
            subPhones
        );
        
        vm.warp(currentTime + 3 seconds);
        
        // Agent 4: All permissions
        enhanced.createAgentWithAnalytics(
            agent4,
            "Store 4",
            "Address 4",
            "Phone",
            "Note",
            allPermissions,
            subLocations,
            subPhones
        );
        
        // Test 1: Get all agents (no permission filter)
        // bool[3] memory noFilter = [false, false, false];
        (
            AgentInfo[] memory allAgentsPage1,
            uint256 totalCount,
            uint256 totalPages,
            uint256 currentPage
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0, // from time
            currentTime+4, // to time
            "createdAt", // sort by
            true, // ascending
            1, // page
            10, // page size
            noFilter
        );
        
        assertEq(totalCount, 4, "Should have 4 total agents");
        assertEq(allAgentsPage1.length, 4, "Page should have 4 agents");
        assertEq(currentPage, 1);
        
        // Test 2: Filter by IQR permission only
        bool[3] memory iqrFilter = [true, false, false];
        (
            AgentInfo[] memory iqrAgents,
            uint256 iqrCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            10,
            iqrFilter
        );
        
        assertEq(iqrCount, 3, "Should have 3 agents with IQR");
        assertEq(iqrAgents.length, 3);
        
        // Verify all returned agents have IQR permission
        for (uint i = 0; i < iqrAgents.length; i++) {
            assertTrue(iqrAgents[i].permissions[0], "Agent should have IQR permission");
        }
        
        // Test 3: Filter by Loyalty permission only
        bool[3] memory loyaltyFilter = [false, true, false];
        (
            AgentInfo[] memory loyaltyAgents,
            uint256 loyaltyCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            10,
            loyaltyFilter
        );
        
        assertEq(loyaltyCount, 3, "Should have 3 agents with Loyalty");
        
        // Test 4: Filter by all permissions (AND logic)
        bool[3] memory allFilter = [true, true, true];
        (
            AgentInfo[] memory fullPermAgents,
            uint256 fullPermCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            10,
            allFilter
        );
        
        assertEq(fullPermCount, 2, "Should have 2 agents with all permissions");
        
        // Verify all returned agents have all permissions
        for (uint i = 0; i < fullPermAgents.length; i++) {
            assertTrue(fullPermAgents[i].permissions[0], "Should have IQR");
            assertTrue(fullPermAgents[i].permissions[1], "Should have Loyalty");
            assertTrue(fullPermAgents[i].permissions[2], "Should have MeOS");
        }
        
        // Test 5: Pagination with small page size
        (
            AgentInfo[] memory page1,
            uint256 count,
            uint256 pages,
            uint256 currPage
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            2, // Only 2 per page
            noFilter
        );
        
        assertEq(count, 4, "Total should be 4");
        assertEq(pages, 2, "Should have 2 pages");
        assertEq(page1.length, 2, "Page 1 should have 2 agents");
        assertEq(currPage, 1);
        
        // Get page 2
        (
            AgentInfo[] memory page2,
            ,
            ,
            uint256 currPage2
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            2,
            2,
            noFilter
        );
        
        assertEq(page2.length, 2, "Page 2 should have 2 agents");
        assertEq(currPage2, 2);
        
        // Verify no overlap between pages
        assertTrue(page1[0].walletAddress != page2[0].walletAddress);
        
        // Test 6: Sort by creation time descending
        (
            AgentInfo[] memory descendingAgents,
            ,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            false, // descending
            1,
            10,
            noFilter
        );
        
        // Verify sorting - newest first
        assertEq(descendingAgents[0].walletAddress, agent4, "First should be agent4 (newest)");
        assertEq(descendingAgents[3].walletAddress, agent1, "Last should be agent1 (oldest)");
        
        // Test 7: Time range filter
        uint256 midTime = currentTime+ 4 - 2 ;
        (
            AgentInfo[] memory recentAgents,
            uint256 recentCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            midTime,
            block.timestamp,
            "createdAt",
            true,
            1,
            10,
            noFilter
        );
        // Should only get agents 3 and 4 (created in last 2 days)
        assertEq(recentCount, 2, "Should have 2 recent agents");
        
        
        
        console.log("Test 7 PASSED: getAgentsInfoPaginatedWithPermissions");
        //
        vm.warp(currentTime + 7 seconds);
        // Agent 5: No permissions
        enhanced.createAgentWithAnalytics(
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B),
            "Store 5",
            "Address 5",
            "Phone",
            "Note",
            noFilter,
            subLocations,
            subPhones
        );
        
        (
            AgentInfo[] memory agents,
            ,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+7,
            "createdAt",
            false, // descending
            1,
            10,
            noFilter
        );
        console.log("agents.length:",agents.length);
        vm.stopPrank();
    }
    
    function test_GetAgentsInfoPaginatedWithPermissions_EmptyResults() public {
        uint currentTime = 1760091452;
        vm.warp(currentTime);
        vm.startPrank(superAdmin);
        
        // Create agent with only IQR
        bool[3] memory permissions = [true, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        // Try to find agents with all permissions (should be empty)
        bool[3] memory allFilter = [true, true, true];
        (
            AgentInfo[] memory agents,
            uint256 totalCount,
            uint256 totalPages,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime,
            "createdAt",
            true,
            1,
            10,
            allFilter
        );
        
        assertEq(totalCount, 0, "Should have no agents with all permissions");
        assertEq(agents.length, 0, "Result should be empty");
        assertEq(totalPages, 0, "Should have 0 pages");
        
        vm.stopPrank();
        
        console.log("Test 7b PASSED: Empty results handling");
    }
    // ========================================================================
    // TEST 6: migrateLoyaltyTokens
    // ========================================================================

    // ========================================================================
    // TEST 8: Full Integration Workflow
    // ========================================================================
    
    function test_FullWorkflow_CompleteScenario() public {
        console.log("\n=== FULL INTEGRATION WORKFLOW ===\n");
        
        vm.startPrank(superAdmin);
        
        // STEP 1: Create multiple agents with different configurations
        console.log("Step 1: Creating agents...");
        
        bool[3] memory fullPerms = [true, true, true];
        bool[3] memory partialPerms = [true, true, false];
        string[] memory subLocations = new string[](2);
        subLocations[0] = "Main Branch";
        subLocations[1] = "Secondary Branch";
        string[] memory subPhones = new string[](2);
        subPhones[0] = "0111111111";
        subPhones[1] = "0122222222";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Premium Store",
            "123 Premium St",
            "0123456789",
            "VIP Agent",
            fullPerms,
            subLocations,
            subPhones
        );
        
        vm.warp(block.timestamp + 1 hours);
        
        enhanced.createAgentWithAnalytics(
            agent2,
            "Standard Store",
            "456 Main Ave",
            "0987654321",
            "Standard Agent",
            partialPerms,
            subLocations,
            subPhones
        );
        
        vm.warp(block.timestamp + 1 hours);
        
        enhanced.createAgentWithAnalytics(
            agent3,
            "Budget Store",
            "789 Budget Ln",
            "0555555555",
            "Budget Agent",
            partialPerms,
            subLocations,
            subPhones
        );
        
        console.log("Created 3 agents");
        
        // STEP 2: Update analytics for agents
        console.log("\nStep 2: Updating analytics...");
        
        enhanced.updateAgentAnalytics(agent1, 100, 50000 ether, 80); // High performer
        enhanced.updateAgentAnalytics(agent2, 50, 20000 ether, 40);  // Medium performer
        enhanced.updateAgentAnalytics(agent3, 20, 5000 ether, 15);   // Low performer
        
        AgentAnalytics memory agent1Analytics = enhanced.getAgentAnalytics(agent1);
        console.log("Agent1 performance score:", agent1Analytics.performanceScore);
        assertGt(agent1Analytics.performanceScore, 50, "Agent1 should have high score");
        
        // STEP 3: Mint loyalty tokens for agents with loyalty permission
        console.log("\nStep 3: Minting loyalty tokens...");
        
        address loyalty1 = enhanced.agentLoyaltyContracts(agent1);
        address loyalty2 = enhanced.agentLoyaltyContracts(agent2);
        
        vm.stopPrank();
        
        vm.prank(agent1);
        AgentLoyalty(loyalty1).mint(customer1, 1000 ether, "Customer1 rewards");
        
        vm.prank(agent1);
        AgentLoyalty(loyalty1).mint(customer2, 500 ether, "Customer2 rewards");
        
        vm.prank(agent2);
        AgentLoyalty(loyalty2).mint(customer1, 750 ether, "Customer1 at store2");
        
        console.log("Minted loyalty tokens for customers");
        
        // STEP 4: Test pagination with filters
        console.log("\nStep 4: Testing pagination...");
        
        vm.startPrank(superAdmin);
        
        bool[3] memory loyaltyFilter = [false, true, false];
        (
            AgentInfo[] memory loyaltyAgents,
            uint256 loyaltyCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            block.timestamp,
            "createdAt",
            true,
            1,
            10,
            loyaltyFilter
        );
        
        console.log("Agents with loyalty:", loyaltyCount);
        assertEq(loyaltyCount, 3, "All agents have loyalty");
        
        // STEP 5: Update an agent
        console.log("\nStep 5: Updating agent...");
        
        string[] memory newSubLoc = new string[](1);
        newSubLoc[0] = "Updated Branch";
        uint[] memory subLocIdx = new uint[](1);
        subLocIdx[0] = 0;
        
        string[] memory newSubPhone = new string[](1);
        newSubPhone[0] = "0999999999";
        uint[] memory subPhoneIdx = new uint[](1);
        subPhoneIdx[0] = 0;
        
        enhanced.updateAgent(
            agent2,
            "Updated Standard Store",
            "New Address",
            "0999999999",
            "Updated",
            fullPerms, // Grant MeOS now
            newSubLoc,
            newSubPhone
        );
        
        Agent memory updatedAgent2 = enhanced.getAgent(agent2);
        assertTrue(updatedAgent2.permissions[2], "Agent2 should now have MeOS");
        console.log("Updated agent2 permissions");
        
        // STEP 6: Migrate loyalty tokens
        console.log("\nStep 6: Migrating loyalty tokens...");
        
        uint256 agent1Supply = AgentLoyalty(loyalty1).totalSupply();
        console.log("Agent1 loyalty supply before migration:", agent1Supply);
        
        uint256 migratedAmount = enhanced.migrateLoyaltyTokens(agent1, agent2);
        console.log("Migrated amount:", migratedAmount);
        
        assertEq(migratedAmount, agent1Supply, "Should migrate all tokens");
        assertTrue(AgentLoyalty(loyalty1).isMigrated(), "Agent1 loyalty should be migrated");
        
        // STEP 7: Lock and unlock tokens
        console.log("\nStep 7: Testing lock/unlock...");
        
        vm.stopPrank();
        
        // Mint tokens to contract itself
        vm.prank(agent2);
        AgentLoyalty(loyalty2).mint(loyalty2, 2000 ether, "Locked rewards");
        
        // Freeze to enable unlock
        vm.prank(agent2);
        AgentLoyalty(loyalty2).freeze();
        
        vm.prank(superAdmin);
        uint256 unlocked = enhanced.unlockLoyaltyTokens(agent2);
        console.log("Unlocked tokens:", unlocked);
        assertEq(unlocked, 2000 ether);
        
        // STEP 8: Delete an agent
        console.log("\nStep 8: Deleting agent...");
        
        vm.startPrank(superAdmin);
        
        // Delete agent3 (has no active unfrozen loyalty)
        enhanced.deleteAgent(agent3);
        
        Agent memory deletedAgent = enhanced.getAgent(agent3);
        assertFalse(deletedAgent.isActive, "Agent3 should be deleted");
        
        Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
        assertEq(deletedAgents.length, 1, "Should have 1 deleted agent");
        console.log("Deleted agent3");
        
        // STEP 9: Get final statistics
        console.log("\nStep 9: Final statistics...");
        
        (
            uint256 totalAgents,
            uint256 activeAgents,
            uint256 totalRevenue,
            uint256 totalOrders,
            uint256 avgPerformance,
            uint256[3] memory permStats
        ) = enhanced.getSystemAnalytics();
        
        console.log("Total agents:", totalAgents);
        console.log("Active agents:", activeAgents);
        console.log("Total revenue:", totalRevenue);
        console.log("Average performance:", avgPerformance);
        console.log("IQR agents:", permStats[0]);
        console.log("Loyalty agents:", permStats[1]);
        console.log("MeOS agents:", permStats[2]);
        
        assertEq(totalAgents, 3, "Should have 3 total agents");
        assertEq(activeAgents, 2, "Should have 2 active agents");
        
        // STEP 10: Get sorted agents
        console.log("\nStep 10: Getting sorted agents...");
        
        (address[] memory topAgents, uint256[] memory scores) = 
            enhanced.getPerformanceLeaderboard(10);
        
        console.log("Top performer:", topAgents[0]);
        console.log("Top score:", scores[0]);
        
        assertEq(topAgents[0], agent1, "Agent1 should be top performer");
        
        vm.stopPrank();
        
        console.log("\n=== FULL WORKFLOW COMPLETED SUCCESSFULLY ===\n");
    }
    
    // ========================================================================
    // TEST 9: Edge Cases and Error Handling
    // ========================================================================
    
    function test_EdgeCases_DuplicateAgent() public {
        vm.startPrank(superAdmin);
        
        bool[3] memory permissions = [true, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        // Create agent
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        // Try to create same agent again - should revert
        vm.expectRevert("DuplicateAgent");
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store 2",
            "Address 2",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        vm.stopPrank();
        
        console.log("Test 9a PASSED: Duplicate agent prevention");
    }
    
    function test_EdgeCases_InvalidAddress() public {
        vm.startPrank(superAdmin);
        
        bool[3] memory permissions = [true, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        // Try to create agent with zero address
        vm.expectRevert("InvalidWallet");
        enhanced.createAgentWithAnalytics(
            address(0),
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLocations,
            subPhones
        );
        
        vm.stopPrank();
        
        console.log("Test 9b PASSED: Invalid address prevention");
    }
    
    function test_EdgeCases_PaginationBoundaries() public {
        vm.startPrank(superAdmin);
        
        bool[3] memory permissions = [true, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        // Create 5 agents
        address[] memory agents = new address[](5);
        for (uint i = 0; i < 5; i++) {
            agents[i] = makeAddr(string(abi.encodePacked("agent", vm.toString(i))));
            enhanced.createAgentWithAnalytics(
                agents[i],
                string(abi.encodePacked("Store ", vm.toString(i))),
                "Address",
                "Phone",
                "Note",
                permissions,
                subLocations,
                subPhones
            );
        }
        
        // Test page beyond range
        bool[3] memory noFilter = [false, false, false];
        (
            AgentInfo[] memory emptyPage,
            uint256 totalCount,
            uint256 totalPages,
            uint256 currentPage
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            block.timestamp,
            "createdAt",
            true,
            999, // Page way beyond range
            10,
            noFilter
        );
        
        assertEq(emptyPage.length, 0, "Should return empty for out of range page");
        assertEq(totalCount, 5, "Total count should still be correct");
        assertGt(totalPages, 0, "Should have valid total pages");
        
        vm.stopPrank();
        
        console.log("Test 9c PASSED: Pagination boundaries");
    }
    
    function test_EdgeCases_NonExistentAgent() public {
        vm.startPrank(superAdmin);
        
        // Try to update non-existent agent
        bool[3] memory permissions = [true, false, false];
        string[] memory subLoc = new string[](0);
        uint[] memory subLocIdx = new uint[](0);
        string[] memory subPhone = new string[](0);
        uint[] memory subPhoneIdx = new uint[](0);
        
        vm.expectRevert("AgentNotFound");
        enhanced.updateAgent(
            agent1, // Doesn't exist
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            subLoc,
            subPhone
        );
        
        // Try to delete non-existent agent
        vm.expectRevert("AgentNotFound");
        enhanced.deleteAgent(agent1);
        
        vm.stopPrank();
        
        console.log("Test 9d PASSED: Non-existent agent handling");
    }
    
    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================
    
    function printAgentInfo(address _agent) internal view {
        Agent memory agent = enhanced.getAgent(_agent);
        console.log("\n--- Agent Info ---");
        console.log("Address:", agent.walletAddress);
        console.log("Store:", agent.storeName);
        console.log("Active:", agent.isActive);
        console.log("IQR:", agent.permissions[0]);
        console.log("Loyalty:", agent.permissions[1]);
        console.log("MeOS:", agent.permissions[2]);
    }
    
    function printSystemStats() internal view {
        (
            uint256 total,
            uint256 active,
            uint256 revenue,
            uint256 orders,
            uint256 avgPerf,
            uint256[3] memory perms
        ) = enhanced.getSystemAnalytics();
        
        console.log("\n--- System Stats ---");
        console.log("Total Agents:", total);
        console.log("Active Agents:", active);
        console.log("Total Revenue:", revenue);
        console.log("Total Orders:", orders);
        console.log("Avg Performance:", avgPerf);
        console.log("IQR Agents:", perms[0]);
        console.log("Loyalty Agents:", perms[1]);
        console.log("MeOS Agents:", perms[2]);
    }
    function GetByteCode()public {
    //
        bytes memory bytesCodeCall = abi.encodeCall(
        enhanced.getAgentsInfoPaginated,
        (
            0,
            1761338782,
            "createdAt",
            false,
            1,
            20
        ));
        console.log("enhanced getAgentsInfoPaginated:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
        //getAgentsInfoPaginatedWithPemissions
        bool[3] memory noFilter = [false, false, false];
        bool[3] memory allFilter = [true,true,true];
        bytesCodeCall = abi.encodeCall(
            enhanced.getAgentsInfoPaginatedWithPemissions,
            (
            1760288400,
            1761338782,
            "createdAt",
            false,
            1,
            20,
            allFilter          
            )
        );
        console.log("getAgentsInfoPaginatedWithPemissions:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
        //enhancedV1.upgradeToAndCall(address(enhancedImplementationV2), "");
        bytesCodeCall = abi.encodeCall(
            enhanced.upgradeToAndCall,
            (
            address(enhancedImplementation), ""            
            ));
        console.log("upgradeToAndCall:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
    //createAgentWithAnalytics
    string[] memory subLocations = new string[](2);
    subLocations[0] = "Branch A";
    subLocations[1] = "Branch B";
    string[] memory subPhones = new string[](2);
    subPhones[0] = "0111111111";
    subPhones[1] = "0122222222";

    bytesCodeCall = abi.encodeCall(
        enhanced.createAgentWithAnalytics,
        (
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B),
            "Store 5",
            "Address 5",
            "Phone",
            "Note",
            allFilter,
            subLocations,
            subPhones
        ));
    console.log("createAgentWithAnalytics:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //getAgentLoyaltyContract
         bytesCodeCall = abi.encodeCall(
        loyaltyFactory.getAgentLoyaltyContract,
        (
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B)
        ));
    console.log("getAgentLoyaltyContract:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    }
}