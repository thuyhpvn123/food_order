// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import {AgentLoyalty} from "./agentIqr.sol";

contract LoyaltyFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    string public version;
    
    mapping(address => address) public agentLoyaltyContracts;
    address[] public deployedContracts;
    
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
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function createAgentLoyalty(address _agent) external onlyOwner returns (address) {
        require(_agent != address(0), "Invalid agent");
        require(agentLoyaltyContracts[_agent] == address(0), "Contract already exists");
        
        AgentLoyalty newContract = new AgentLoyalty(_agent,msg.sender);
        address contractAddr = address(newContract);
        
        agentLoyaltyContracts[_agent] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentLoyaltyCreated(_agent, contractAddr, block.timestamp);
        return contractAddr;
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
    
    uint256[50] private __gap;
}
