// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import {AgentIQR} from "./agentIqr.sol";

contract IQRFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    string public version;
    
    mapping(address => address) public agentIQRContracts;
    address[] public deployedContracts;
    address public enhancedAgent;
    address public MANAGEMENT;
    address public ORDER;
    address public REPORT;
    address public TIMEKEEPING;

    event AgentIQRCreated(address indexed agent, address indexed contractAddr, uint256 timestamp);
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
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setIQRSC(
        address _MANAGEMENT,
        address _ORDER,
        address _REPORT,
        address _TIMEKEEPING
    )external onlyOwner {
        MANAGEMENT = _MANAGEMENT;
        ORDER = _ORDER;
        REPORT = _REPORT;
        TIMEKEEPING = _TIMEKEEPING;
    }
    function createAgentIQR(address _agent) external onlyOwner returns (address) {
        require(MANAGEMENT != address(0) && ORDER != address(0) && REPORT != address(0) && TIMEKEEPING != address(0),
            "addresses of iqr can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentIQRContracts[_agent] == address(0), "Contract already exists");
        
        AgentIQR newContract = new AgentIQR(_agent,enhancedAgent,MANAGEMENT,ORDER,REPORT,TIMEKEEPING);
        address contractAddr = address(newContract);
        
        agentIQRContracts[_agent] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentIQRCreated(_agent, contractAddr, block.timestamp);
        return contractAddr;
    }
    
    function getAgentIQRContract(address _agent) external view returns (address) {
        return agentIQRContracts[_agent];
    }
    
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    
    function getVersion() external view returns (string memory) {
        return version;
    }
    
    uint256[50] private __gap;
}


