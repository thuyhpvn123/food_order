// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
// STRUCTS - Shared data structures
// ============================================================================
struct IQRContracts {
    address Management;
    address Order;
    address Report;
    address TimeKeeping;
    address owner;      
}
struct AgentInfo {
    address walletAddress;
    string storeName;
    string storeAddress;
    uint256 numOfBranch;
    bool[3] permissions;
    uint256 createdAt;
    uint256[3] revenueByModule;
}
struct Agent {
    address walletAddress;
    string storeName;
    string storeAddress;
    string phone;
    string note;
    bool[3] permissions; // [IQR, Loyalty, MeOS]
    string[] subLocations;
    string[] subPhones;
    uint256 createdAt;
    uint256 updatedAt;
    bool isActive;
    bool exists;
}

struct MeOSLicense {
    string licenseKey;
    bool isActive;
    uint256 createdAt;
    uint256 expiryAt;
}

struct MTDStats {
    uint256 totalSupply;
    uint256 available;
    uint256 locked;
    uint256 burned;
    uint256 frozen;
}

struct AgentOrder {
    uint256 orderId;
    address customer;
    uint256 amount;
    uint256 timestamp;
    bool completed;
    string metadata;
}

struct Revenue {
    uint256 iqr;
    uint256 loyalty;
    uint256 meos;
    uint256 total;
}

struct AgentRevenue {
    address agent;
    uint256 iqr;
    uint256 loyalty;
    uint256 meos;
    uint256 total;
    uint256 lastUpdated;
}

struct RevenueRecord {
    address agent;
    uint8 moduleType; // 1=IQR, 2=Loyalty, 3=MeOS
    uint256 amount;
    uint256 timestamp;
    string metadata;
}

struct RewardTransaction {
    address user;
    uint256 amount;
    string transactionType; // "mint", "burn", "redeem"
    uint256 timestamp;
    string metadata;
}

struct PaginationResult {
    address[] agents;
    uint totalCount;
    uint currentPage;
    uint totalPages;
    bool hasNext;
    bool hasPrev;
}

struct AgentAnalytics {
    uint256 totalOrders;
    uint256 totalRevenue;
    uint256 loyaltyTokensIssued;
    uint256 meosLicensesActive;
    uint256 customerCount;
    uint256 averageOrderValue;
    uint256 lastActivityTimestamp;
    uint256 performanceScore; // 0-100
}

struct TimeFilter {
    uint256 startTime;
    uint256 endTime;
    string period; // "day", "week", "month", "year"
}

struct License {
    string licenseKey;
    address agent;
    bool isActive;
    uint256 createdAt;
    uint256 expiryAt;
    uint256 installCount;
    uint256 maxInstalls;
    string version;
    bytes32 hardwareFingerprint;
}

// ============================================================================
// INTERFACES
// ============================================================================

interface IIQRFactory {
    function createAgentIQR(address _agent) external returns (address);
    function getAgentIQRContract(address _agent) external view returns (address);
}

interface ILoyaltyFactory {
    function createAgentLoyalty(address _agent) external returns (address);
    function getAgentLoyaltyContract(address _agent) external view returns (address);
}

interface IAgentLoyalty {
    function totalSupply() external view returns (uint256);
    function freeze() external;
    function unfreeze() external;
    function setRedeemOnly(uint256 _days) external;
    function unlockTokens() external returns (uint256);
    function migrateTo(address _newContract) external returns (uint256);
    function isFrozen() external view returns (bool);
    function isRedeemOnly() external view returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address _to, uint256 _amount, string memory _metadata) external;
}

interface IAgentIQR {
    function getTotalRevenue() external view returns (uint256);
    function deactivate() external;
    function isActive() external view returns (bool);
}

interface IRevenueManager {
    function addAgent(address _agent) external;
    function recordRevenue(address _agent, uint8 _moduleType, uint256 _amount, string memory _metadata) external;
    function getAgentRevenue(address _agent) external view returns (uint256, uint256, uint256, uint256);
    function getSystemRevenue() external view returns (uint256, uint256, uint256, uint256);
}

interface IMTDToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IAgentManagement {
    function getAgent(address _agent) external view returns (Agent memory);
    function getAllAgents() external view returns (address[] memory);
    function getActiveAgents() external view returns (address[] memory);
    function getSubLocationCount(address _agent) external view returns (uint256);
}