// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interfaces/IPoint.sol";
import {RestaurantLoyaltySystem} from "./agentLoyalty.sol";

contract LoyaltyFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    string public version;
    
    mapping(address => address) public agentLoyaltyContracts;
    address[] public deployedContracts;
    address public enhancedAgent;
    address public POINTS_IMP;
    uint256[50] private __gap;
    
    event AgentLoyaltyCreated(address indexed agent, address indexed contractAddr, uint256 timestamp);
    event ContractUpgraded(string oldVersion, string newVersion, uint256 timestamp);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        version = "1.0.0";
    }
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setPointsImp(address _pointsImp) external onlyOwner {
        POINTS_IMP = _pointsImp;
    }
    
    function createAgentLoyalty(address _agent) external onlyEnhanceSC returns (address) {
        require(_agent != address(0), "Invalid agent");
        require(agentLoyaltyContracts[_agent] == address(0), "Contract already exists");
        require(POINTS_IMP != address(0),"POINTS_IMP not set yet");
        
        // AgentLoyalty newContract = new AgentLoyalty(_agent,msg.sender);
        ERC1967Proxy POINTS_PROXY = new ERC1967Proxy(
            POINTS_IMP, 
            abi.encodeWithSelector(IPoint.initialize.selector,
             _agent,
             msg.sender)
        );

        address contractAddr = address(POINTS_PROXY);
        
        agentLoyaltyContracts[_agent] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentLoyaltyCreated(_agent, contractAddr, block.timestamp);
        return contractAddr;
    }
    //admin gọi ngay sau gọi createAgent nếu có dùng loyalty
    function setPointsLoyaltyFactory(address _agent, address _Management,address _Order) external onlyEnhanceSC returns(address) {
        address POINTS_PROXY = agentLoyaltyContracts[_agent];
        IPoint(POINTS_PROXY).setManagementSC(_Management);
        IPoint(POINTS_PROXY).setOrder(_Order);
        return POINTS_PROXY;
    }
    function transferOwnerPointSC(address _agent, address POINTS_PROXY)external onlyEnhanceSC {
        require(POINTS_PROXY != address(0),"POINTS_IMP not set yet");
        IPoint(POINTS_PROXY).transferOwnership(_agent);
    }
    function getAgentLoyaltyContract(address _agent) external view returns (address) {
        return agentLoyaltyContracts[_agent];
    }
    
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    
    function getVersion() external view returns (string memory) {
        return version;
    }
    
}
