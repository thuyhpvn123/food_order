// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IAgent.sol";
import {AgentIQR} from "./agentIqr.sol";
import {RestaurantLoyaltySystem} from "./agentLoyalty.sol";
import {IQRFactory} from "./iqrFactory.sol";
// import "forge-std/console.sol";
contract AgentManagement is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    
    // Version for upgrade tracking
    string public version;
    
    // Admin state
    address public superAdmin;
    bool public adminInitialized;
    
    // Contract addresses
    address public iqrFactory;
    address public loyaltyFactory;
    address public revenueManager;
    address public mtdToken;
    
    // Mappings
    mapping(address => Agent) public agents;
    mapping(address => address) public agentIQRContracts;
    mapping(address => address) public agentLoyaltyContracts;
    mapping(address => MeOSLicense) public meosLicenses;
    address[] public agentList;
    
    // Pause functionality
    bool public paused ;
    Agent[] public deletedAgents;
    mapping(address => bool) public isAdmin;
    mapping(string => address) public mDomainToWallet;
    mapping(address => string) public mAgentToDomain;
    uint256[48] private __gap;
    // Events
    event SuperAdminSet(address indexed admin);
    event AgentCreated(address indexed agent, string storeName, uint256 timestamp);
    event AgentUpdated(address indexed agent, uint256 timestamp);
    event AgentDeleted(address indexed agent, uint256 timestamp);
    event PermissionGranted(address indexed agent, uint8 permissionType, uint256 timestamp);
    event PermissionRevoked(address indexed agent, uint8 permissionType, uint256 timestamp);
    event MeOSLicenseIssued(address indexed agent, string licenseKey, uint256 expiryAt);
    event LoyaltyTokensUnlocked(address indexed agent, uint256 amount);
    event LoyaltyTokensMigrated(address indexed fromAgent, address indexed toAgent, uint256 amount);
    event ContractUpgraded(string oldVersion, string newVersion, uint256 timestamp);
    event ContractPausedEvent(uint256 timestamp);
    event ContractUnpaused(uint256 timestamp);
    
    modifier onlySuperAdmin() {
        require(isAdmin[msg.sender] == true, "OnlySuperAdmin");
        _;
    }
    
    modifier validAgent(address _agent) {
        require(agents[_agent].exists,"AgentNotFound");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused,"ContractPaused");
        _;
    }
    
    // ========================================================================
    // INITIALIZER (REPLACES CONSTRUCTOR)
    // ========================================================================
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the contract (replaces constructor)
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        version = "1.0.0";
        // adminInitialized = false;
        paused = false;
        isAdmin[msg.sender] = true;
    }
    
    /**
     * @dev Authorize upgrade (only owner can upgrade)
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ========================================================================
    // ADMIN INITIALIZATION
    // ========================================================================
    

    function setAdmin(address _adminWallet) external onlyOwner {
        require(_adminWallet != address(0), "InvalidWallet");       
        // _transferOwnership(_adminWallet);
        isAdmin[_adminWallet] = true;
        emit SuperAdminSet(_adminWallet);
    }
    
    /**
     * @dev Set factory contract addresses
     */
    function setFactoryContracts(
        address _iqrFactory,
        address _loyaltyFactory,
        address _revenueManager
        // address _mtdToken
    ) external onlySuperAdmin {
        iqrFactory = _iqrFactory;
        loyaltyFactory = _loyaltyFactory;
        revenueManager = _revenueManager;
        // mtdToken = _mtdToken;
    }
    
    function getSubLocationCount(address _agent) public view returns (uint256) {
        return agents[_agent].subLocations.length;
    }

    /**
     * @dev Grant permissions to agent
     */
    function _grantPermissions(address _agent, bool[3] memory _permissions) internal {
        if (_permissions[0]) {
            _grantIQRPermission(_agent);
        }
        
        // Loyalty Permission  
        if (_permissions[1]) {
            require(_permissions[0],"need iqr permission also to set this permission");
            _grantLoyaltyPermission(_agent);
        }
        
        // MeOS Permission
        if (_permissions[2]) {
            _grantMeOSPermission(_agent);
        }
    }
    function _grantIQRPermission(address _agent) internal {
        if (iqrFactory == address(0)) {
            agents[_agent].permissions[0] = false;
            return;
        }
        address agentIQR = IQRFactory(iqrFactory).createAgentIQR(_agent);
        agentIQRContracts[_agent] = agentIQR;
        emit PermissionGranted(_agent, 0, block.timestamp);

    }

    /**
     * @dev Grant Loyalty permission by deploying contract
     */
    function _grantLoyaltyPermission(address _agent) internal {
        if (loyaltyFactory == address(0)) {
            agents[_agent].permissions[1] = false;
            return;
        }
        
        address contractAddr = ILoyaltyFactory(loyaltyFactory).createAgentLoyalty(_agent);
            agentLoyaltyContracts[_agent] = contractAddr;            // la contract Points
            emit PermissionGranted(_agent, 1, block.timestamp);
    }
    
    /**
     * @dev Grant MeOS permission by generating license key
     */
    function _grantMeOSPermission(address _agent) internal {
        string memory licenseKey = _generateLicenseKey(_agent);
        uint256 expiryAt = block.timestamp + (365 * 24 * 60 * 60); // 1 year
        
        meosLicenses[_agent] = MeOSLicense({
            licenseKey: licenseKey,
            isActive: true,
            createdAt: block.timestamp,
            expiryAt: expiryAt
        });
        
        emit MeOSLicenseIssued(_agent, licenseKey, expiryAt);
        emit PermissionGranted(_agent, 2, block.timestamp);
    }
    
    /**
     * @dev Generate unique license key for MeOS
     */
    function _generateLicenseKey(address _agent) internal view returns (string memory) {
        return string(abi.encodePacked(
            "MEOS-",
            Strings.toHexString(uint160(_agent), 20),
            "-",
            Strings.toString(block.timestamp)
        ));
    }
    
    /**
     * @dev Update agent information and permissions
     */
    function updateAgent(
        address _agent,
        string memory _storeName,
        string memory _address,
        string memory _phone,
        string memory _note,
        bool[3] memory _permissions,
        string[] memory _subLocations,
        string[] memory _subPhones,
        string memory _domain
    ) external onlySuperAdmin validAgent(_agent) whenNotPaused nonReentrant {
        require( mDomainToWallet[_domain] == address(0),"domain was used");
        Agent storage agent = agents[_agent];
        
        // Update basic info
        agent.storeName = _storeName;
        agent.storeAddress = _address;
        agent.phone = _phone;
        agent.note = _note;
        agent.updatedAt = block.timestamp;
        agent.domain = _domain;
        if(_subLocations.length>0){
            delete agent.subLocations;

            for(uint i; i < _subLocations.length ;i++){
                agent.subLocations.push(_subLocations[i]);
            }
        }
        if(_subPhones.length>0){
            delete agent.subPhones;
            for(uint i; i < _subPhones.length ;i++){
                agent.subPhones.push(_subPhones[i]);
            }
        }

        // Update permissions
        _updatePermissions(_agent, _permissions);
        mDomainToWallet[_domain] = agent.walletAddress;
        mAgentToDomain[agent.walletAddress] = _domain;

        emit AgentUpdated(_agent, block.timestamp);
    }
    
    /**
     * @dev Update agent permissions
     */
    function _updatePermissions(address _agent, bool[3] memory _newPermissions) internal {
        Agent storage agent = agents[_agent];
        
        for (uint8 i = 0; i < 3; i++) {
            if (agent.permissions[i] != _newPermissions[i]) {
                if (_newPermissions[i]) {
                    // Grant permission
                    if (i == 0) _grantIQRPermission(_agent);
                    else if (i == 1) _grantLoyaltyPermission(_agent);
                    else if (i == 2) _grantMeOSPermission(_agent);
                } else {
                    // Revoke permission
                    _revokePermission(_agent, i);
                }
                agent.permissions[i] = _newPermissions[i];
            }
        }
    }
    
    /**
     * @dev Revoke specific permission
     */
    function _revokePermission(address _agent, uint8 _permissionType) internal {
        if (_permissionType == 0) { // IQR
            address iqrContract = agentIQRContracts[_agent];
            if (iqrContract != address(0)) {
                IAgentIQR(iqrContract).deactivate();
            }
        } else if (_permissionType == 1) { // Loyalty
            address loyaltyContract = agentLoyaltyContracts[_agent];
            if (loyaltyContract != address(0)) {
                IRestaurantLoyaltySystem(loyaltyContract).freeze();
            }
        } else if (_permissionType == 2) { // MeOS
            meosLicenses[_agent].isActive = false;
        }
        
        emit PermissionRevoked(_agent, _permissionType, block.timestamp);
    }
    
    /**
     * @dev Delete agent (with loyalty token check)
     */
    function deleteAgent(address _agent) external onlySuperAdmin validAgent(_agent) whenNotPaused nonReentrant {
        // Check if has active loyalty tokens
        if (agents[_agent].permissions[1]) {
            address loyaltyContract = agentLoyaltyContracts[_agent];
            if (loyaltyContract != address(0)) {
                uint256 supply = IRestaurantLoyaltySystem(loyaltyContract).totalSupply(); 
                bool isFrozen = IRestaurantLoyaltySystem(loyaltyContract).isFrozen(); 
                bool isRedeemOnly = IRestaurantLoyaltySystem(loyaltyContract).isRedeemOnly();
                require(!(supply > 0 && !isFrozen && !isRedeemOnly),"HasActiveLoyaltyTokens");
            }
        }
        
        // Revoke all permissions first
        bool[3] memory noPermissions = [false, false, false];
        _updatePermissions(_agent, noPermissions);
        
        // Mark as deleted
        agents[_agent].isActive = false;
        agents[_agent].updatedAt = block.timestamp;
        deletedAgents.push(agents[_agent]);
        emit AgentDeleted(_agent, block.timestamp);
    }
    function getDeletedAgentd() external view returns(Agent[] memory){
        return deletedAgents;
    }

/**
 * @dev Get deleted agents with pagination and search filter
 * @param _page Page number (starts from 1)
 * @param _pageSize Number of items per page
 * @param _searchTerm Search term for store name or wallet address (empty string for no filter)
 * @return agentArr Array of deleted agent information
 * @return totalCount Total number of matching deleted agents
 * @return totalPages Total number of pages
 * @return currentPage Current page number
 */
function getDeletedAgentsPaginated(
    uint256 _page,
    uint256 _pageSize,
    string memory _searchTerm
) external view returns (
    Agent[] memory agentArr,
    uint256 totalCount,
    uint256 totalPages,
    uint256 currentPage
) {
    // Filter deleted agents by search term
    Agent[] memory filtered;
    bytes memory searchBytes = bytes(_searchTerm);
    
    if (searchBytes.length > 0) {
        filtered = _filterDeletedAgentsBySearch(searchBytes);
    } else {
        filtered = deletedAgents;
    }
    
    totalCount = filtered.length;
    totalPages = totalCount > 0 ? (totalCount + _pageSize - 1) / _pageSize : 0;
    currentPage = _page;
    
    // Validate page number
    if (_page == 0 || _page > totalPages || totalCount == 0) {
        return (new Agent[](0), totalCount, totalPages, currentPage);
    }
    
    // Calculate pagination indices
    uint256 startIndex = (_page - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    if (endIndex > totalCount) {
        endIndex = totalCount;
    }
    
    // Build page result
    uint256 pageLength = endIndex - startIndex;
    Agent[] memory pageResult = new Agent[](pageLength);
    
    for (uint256 i = 0; i < pageLength; i++) {
        pageResult[i] = filtered[startIndex + i];
    }
    
    return (pageResult, totalCount, totalPages, currentPage);
}
/**
 * @dev Filter deleted agents by search term (store name or wallet address)
 * @param _searchBytes Search term in bytes
 * @return Agent[] Filtered array of deleted agents
 */
function _filterDeletedAgentsBySearch(
    bytes memory _searchBytes
) internal view returns (Agent[] memory) {
    // Count matching deleted agents
    uint256 count = 0;
    for (uint256 i = 0; i < deletedAgents.length; i++) {
        if (_matchesSearchDeletedAgent(deletedAgents[i], _searchBytes)) {
            count++;
        }
    }
    
    // Build filtered array
    Agent[] memory filtered = new Agent[](count);
    uint256 index = 0;
    
    for (uint256 i = 0; i < deletedAgents.length; i++) {
        if (_matchesSearchDeletedAgent(deletedAgents[i], _searchBytes)) {
            filtered[index] = deletedAgents[i];
            index++;
        }
    }
    
    return filtered;
}
/**
 * @dev Helper function to check if deleted agent matches search criteria
 * @param _agent Agent struct to check
 * @param _searchBytes Search term in bytes
 * @return bool True if agent matches search term
 */
function _matchesSearchDeletedAgent(
    Agent memory _agent,
    bytes memory _searchBytes
) internal pure returns (bool) {
    // Search in store name
    bytes memory storeNameBytes = bytes(_agent.storeName);
    if (_containsIgnoreCaseDeletedAgent(storeNameBytes, _searchBytes)) {
        return true;
    }
    
    // Search in wallet address
    // Convert address to hex string for comparison
    string memory walletStr = _addressToString(_agent.walletAddress);
    bytes memory walletBytes = bytes(walletStr);
    
    // Convert search term to lowercase
    bytes memory searchLower = _toLowerBytes(_searchBytes);
    
    if (_containsIgnoreCaseDeletedAgent(walletBytes, searchLower)) {
        return true;
    }
    
    return false;
}

/**
 * @dev Helper function to check if bytes contains substring (case-insensitive)
 * @param _haystack The string to search in
 * @param _needle The string to search for
 * @return bool True if needle is found in haystack
 */
function _containsIgnoreCaseDeletedAgent(
    bytes memory _haystack,
    bytes memory _needle
) internal pure returns (bool) {
    if (_needle.length > _haystack.length) return false;
    if (_needle.length == 0) return true;
    
    // Convert both to lowercase for comparison
    bytes memory haystackLower = _toLowerBytes(_haystack);
    bytes memory needleLower = _toLowerBytes(_needle);
    
    // Search for substring
    for (uint256 i = 0; i <= haystackLower.length - needleLower.length; i++) {
        bool isMatch = true;
        for (uint256 j = 0; j < needleLower.length; j++) {
            if (haystackLower[i + j] != needleLower[j]) {
                isMatch = false;
                break;
            }
        }
        if (isMatch) return true;
    }
    
    return false;
}

/**
 * @dev Convert bytes to lowercase
 * @param _input Bytes to convert
 * @return bytes Lowercase bytes
 */
function _toLowerBytes(bytes memory _input) internal pure returns (bytes memory) {
    bytes memory result = new bytes(_input.length);
    
    for (uint256 i = 0; i < _input.length; i++) {
        bytes1 char = _input[i];
        if (char >= 0x41 && char <= 0x5A) { // A-Z
            result[i] = bytes1(uint8(char) + 32);
        } else {
            result[i] = char;
        }
    }
    
    return result;
}

/**
 * @dev Convert address to lowercase hex string (without 0x prefix)
 * @param _addr Address to convert
 * @return string Lowercase hex string
 */
function _addressToString(address _addr) internal pure returns (string memory) {
    bytes memory alphabet = "0123456789abcdef";
    bytes memory str = new bytes(40); // 20 bytes * 2 chars per byte
    
    uint160 addrUint = uint160(_addr);
    
    for (uint256 i = 0; i < 20; i++) {
        str[i * 2] = alphabet[uint8(addrUint >> ((19 - i) * 8 + 4)) & 0xf];
        str[i * 2 + 1] = alphabet[uint8(addrUint >> ((19 - i) * 8)) & 0xf];
    }
    
    return string(str);
}
    // ========================================================================
    // LOYALTY TOKEN MANAGEMENT
    // ========================================================================
    
    /**
     * @dev Unlock loyalty tokens for agent
     */
    function unlockLoyaltyTokens(address _agent) 
        external 
        onlySuperAdmin 
        validAgent(_agent) 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        address loyaltyContract = agentLoyaltyContracts[_agent];
        if (loyaltyContract == address(0)) return 0;
        uint unlockedAmount =  IRestaurantLoyaltySystem(loyaltyContract).unlockTokens();
        emit LoyaltyTokensUnlocked(_agent, unlockedAmount);
        return unlockedAmount;

    }
    
        // ============================================================================
    // UPDATED AGENT MANAGEMENT CONTRACT - MIGRATION FUNCTION
    // ============================================================================

    /**
    * @dev Migrate loyalty tokens from old agent to new agent (FULL IMPLEMENTATION)
    * This handles complete migration including all user balances
    */
    function migrateLoyaltyTokens(
        address _oldAgent, 
        address _newAgent
    ) 
        external 
        onlySuperAdmin 
        whenNotPaused 
        nonReentrant 
        returns (
            uint256 totalMigrated
            // uint256 userCount,
            // bool success
        ) 
    {
        uint256 userCount;
        bool success;
        require(agents[_oldAgent].exists && agents[_newAgent].exists, "Agent not found");
        require(_oldAgent != _newAgent, "Cannot migrate to same agent");
        
        address oldContract = agentLoyaltyContracts[_oldAgent];
        address newContract = agentLoyaltyContracts[_newAgent];
        
        require(oldContract != address(0), "Old contract not found");
        require(newContract != address(0), "New contract not found");
        require(oldContract != newContract, "Contracts are the same");
        
        RestaurantLoyaltySystem oldLoyalty = RestaurantLoyaltySystem(oldContract);
        RestaurantLoyaltySystem newLoyalty = RestaurantLoyaltySystem(newContract);
        
        // Verify old contract is not already migrated
        require(!oldLoyalty.migrated(), "Old contract already migrated");
        
        // PHASE 1: Initiate migration on old contract
        oldLoyalty.migrateTo(newContract);
            
        // PHASE 2: Get all token holders and their balances
        (address[] memory holders, uint256[] memory balances) = 
            oldLoyalty.getTokenHoldersWithBalances();
        if (holders.length == 0) {
            emit LoyaltyTokensMigrated(_oldAgent, _newAgent, 0);
            // return (0, 0, true);
            return 0;
        }
        
        // PHASE 3: Receive migration in new contract (batch process)
        uint256 received = newLoyalty.receiveMigration(oldContract, holders, balances) ;
            totalMigrated = received;
            userCount = holders.length;
            success = true;
            
            emit LoyaltyTokensMigrated(_oldAgent, _newAgent, totalMigrated);
            
            // return (totalMigrated, userCount, true);
            return totalMigrated;
                            
    }

    /**
    * @dev Get migration status for an agent
    */
    function getLoyaltyMigrationStatus(address _agent)
        external
        view
        validAgent(_agent)
        returns (
            bool hasMigrated,
            address migratedTo,
            uint256 totalMigrated,
            uint256 remainingSupply,
            uint256 tokenHolderCount
        )
    {
        address loyaltyContract = agentLoyaltyContracts[_agent];
        if (loyaltyContract == address(0)) {
            return (false, address(0), 0, 0, 0);
        }
        
        RestaurantLoyaltySystem loyalty = RestaurantLoyaltySystem(loyaltyContract);
        
        (bool migrated, address migratedToAddr, uint256 migrated_amount, uint256 remaining) = 
            loyalty.getMigrationInfo();
        
        address[] memory holders = loyalty.getTokenHolders();
        
        return (migrated, migratedToAddr, migrated_amount, remaining, holders.length);
    }

    /**
    * @dev Verify migration completion
    */
    function verifyLoyaltyMigration(address _oldAgent, address _newAgent)
        external
        view
        returns (
            bool oldContractMigrated,
            bool allUsersMigrated,
            uint256 oldContractSupply,
            uint256 newContractSupply,
            string memory status
        )
    {
        address oldContract = agentLoyaltyContracts[_oldAgent];
        address newContract = agentLoyaltyContracts[_newAgent];
        
        if (oldContract == address(0) || newContract == address(0)) {
            return (false, false, 0, 0, "Contracts not found");
        }
        
        RestaurantLoyaltySystem oldLoyalty = RestaurantLoyaltySystem(oldContract);
        RestaurantLoyaltySystem newLoyalty = RestaurantLoyaltySystem(newContract);
        
        oldContractMigrated = oldLoyalty.migrated();
        // (,, uint256 migrated,) = oldLoyalty.getMigrationInfo();
        (uint256 oldSupply,,,,) = oldLoyalty.getTokenStats();
        (uint256 newSupply,,,,) = newLoyalty.getTokenStats();
        
        oldContractSupply = oldSupply;
        newContractSupply = newSupply;
        
        if (!oldContractMigrated) {
            status = "Migration not initiated";
            return (false, false, oldSupply, newSupply, status);
        }
        
        if (oldSupply == 0 && newSupply > 0) {
            allUsersMigrated = true;
            status = "Migration completed successfully";
        } else if (oldSupply > 0) {
            allUsersMigrated = false;
            status = "Migration incomplete - users still have balance in old contract";
        } else {
            status = "Unknown state";
        }
    }   

    /**
     * @dev Set loyalty contract to redeem-only mode
     */
    function setLoyaltyRedeemOnly(address _agent, uint256 _days) 
        external 
        onlySuperAdmin 
        validAgent(_agent) 
        whenNotPaused 
    {
        address loyaltyContract = agentLoyaltyContracts[_agent];
       require(loyaltyContract != address(0),"ContractNotSet");
        
        IRestaurantLoyaltySystem(loyaltyContract).setRedeemOnly(_days);
    }
    
    // ========================================================================
    // DASHBOARD & ANALYTICS
    // ========================================================================
    
    /**
     * @dev Get dashboard metrics
     */
    function getDashboardMetrics() external view returns (
        MTDStats memory mtdStats,
        uint256[4] memory revenue, // [iqr, loyalty, meos, total]
        uint256 totalAgents,
        uint256 activeAgents
    ) {
        // MTD Stats
        if (mtdToken != address(0)) {
            uint256 supply = IMTDToken(mtdToken).totalSupply();
            mtdStats.totalSupply = supply;
            // uint256 balance = IMTDToken(mtdToken).balanceOf(address(this));
        }
        
        // Revenue Stats
        if (revenueManager != address(0)) {
            (uint256 iqr, uint256 loyalty, uint256 meos, uint256 total) = IRevenueManager(revenueManager).getSystemRevenue();               
                revenue[0] = iqr;
                revenue[1] = loyalty;
                revenue[2] = meos;
                revenue[3] = total;
        }
        
        // Agent Stats
        totalAgents = agentList.length;
        activeAgents = getActiveAgentsCount();
    }
    
    /**
     * @dev Get revenue details for specific agent
     */
    function getAgentRevenueDetail(address _agent) 
        external 
        view 
        validAgent(_agent)
        returns (uint256 iqr, uint256 loyalty, uint256 meos, uint256 total) 
    {
        if (revenueManager != address(0)) {
            try IRevenueManager(revenueManager).getAgentRevenue(_agent) returns (
                uint256 _iqr, uint256 _loyalty, uint256 _meos, uint256 _total
            ) {
                return (_iqr, _loyalty, _meos, _total);
            } catch {
                return (0, 0, 0, 0);
            }
        }
        return (0, 0, 0, 0);
    }
    
    // ========================================================================
    // VIEW FUNCTIONS
    // ========================================================================
    
    /**
     * @dev Get agent information
     */
    function getAgent(address _agent) external view returns (Agent memory) {
        return agents[_agent];
    }
    
    /**
     * @dev Get all agents
     */
    function getAllAgents() external view returns (address[] memory) {
        return agentList;
    }
    
    /**
     * @dev Get active agents only
     */
    function getActiveAgents() public view returns (address[] memory) {
        uint256 activeCount = getActiveAgentsCount();
        address[] memory activeAgentsList = new address[](activeCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                activeAgentsList[index] = agentList[i];
                index++;
            }
        }
        
        return activeAgentsList;
    }
    
    /**
     * @dev Get count of active agents
     */
    function getActiveAgentsCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Get agents by specific permission
     */
    function getAgentsByPermission(uint8 _permissionType) 
        external 
        view 
        returns (address[] memory) 
    {
        require(_permissionType <= 2,"InvalidPermissionType");
        
        uint256 count = 0;
        
        // Count first
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive && agents[agentList[i]].permissions[_permissionType]) {
                count++;
            }
        }
        
        // Fill array
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive && agents[agentList[i]].permissions[_permissionType]) {
                result[index] = agentList[i];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get agents with all permissions
     */
    function getFullPermissionAgents() external view returns (address[] memory) {
        uint256 count = 0;
        
        // Count first
        for (uint256 i = 0; i < agentList.length; i++) {
            Agent memory agent = agents[agentList[i]];
            if (agent.isActive && agent.permissions[0] && agent.permissions[1] && agent.permissions[2]) {
                count++;
            }
        }
        
        // Fill array
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            Agent memory agent = agents[agentList[i]];
            if (agent.isActive && agent.permissions[0] && agent.permissions[1] && agent.permissions[2]) {
                result[index] = agentList[i];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get MeOS license for agent
     */
    function getMeOSLicense(address _agent) 
        external 
        view 
        validAgent(_agent) 
        returns (MeOSLicense memory) 
    {
        return meosLicenses[_agent];
    }
    
    /**
     * @dev Search agents by store name (simple contains search)
     */
    function searchAgentsByStoreName(string memory _searchTerm) 
        external 
        view 
        returns (address[] memory) 
    {
        bytes memory searchBytes = bytes(_searchTerm);
        if (searchBytes.length == 0) {
            return getActiveAgents();
        }
        
        // Count matching agents first
        uint256 matchCount = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                bytes memory storeNameBytes = bytes(agents[agentList[i]].storeName);
                if (_contains(storeNameBytes, searchBytes)) {
                    matchCount++;
                }
            }
        }
        
        // Build result array
        address[] memory results = new address[](matchCount);
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                bytes memory storeNameBytes = bytes(agents[agentList[i]].storeName);
                if (_contains(storeNameBytes, searchBytes)) {
                    results[resultIndex] = agentList[i];
                    resultIndex++;
                }
            }
        }
        
        return results;
    }
    
    /**
     * @dev Helper function to check if bytes contains substring
     */
    function _contains(bytes memory _haystack, bytes memory _needle) 
        internal 
        pure 
        returns (bool) 
    {
        if (_needle.length > _haystack.length) return false;
        if (_needle.length == 0) return true;
        
        for (uint256 i = 0; i <= _haystack.length - _needle.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < _needle.length; j++) {
                if (_haystack[i + j] != _needle[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) return true;
        }
        return false;
    }
    
    /**
     * @dev Get contract version
     */
    function getVersion() external view returns (string memory) {
        return version;
    }
    
    /**
     * @dev Get contract status
     */
    function getContractStatus() external view returns (
        string memory _version,
        bool _paused,
        // bool _adminInitialized,
        // address _superAdmin,
        uint256 _totalAgents,
        uint256 _activeAgents
    ) {
        return (
            version,
            paused,
            // adminInitialized,
            // superAdmin,
            agentList.length,
            getActiveAgentsCount()
        );
    }
    
    // ========================================================================
    // EMERGENCY FUNCTIONS
    // ========================================================================
    
    /**
     * @dev Pause contract operations
     */
    function pause() external onlySuperAdmin {
        paused = true;
        emit ContractPausedEvent(block.timestamp);
    }
    
    /**
     * @dev Unpause contract operations
     */
    function unpause() external onlySuperAdmin {
        paused = false;
        emit ContractUnpaused(block.timestamp);
    }
    
    /**
     * @dev Check if contract is paused
     */
    function isPaused() external view returns (bool) {
        return paused;
    }
} 

