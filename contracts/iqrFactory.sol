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
    address public MANAGEMENT; //chỉ là implement, not proxy
    address public ORDER;
    address public REPORT;
    address public TIMEKEEPING;
    address public cardVisa;
    address public noti;
    address public revenueManager;
    address public StaffAgentStore;
    address public POINTS;
    uint256[50] private __gap;
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
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setIQRSC(
        address _MANAGEMENT, //implement ,not proxy
        address _ORDER,
        address _REPORT,
        address _TIMEKEEPING,
        address _cardVisa,
        address _noti,
        address _revenueManager,
        address _StaffAgentStore
        // address _POINTS
    )external onlyOwner {
        MANAGEMENT = _MANAGEMENT;
        ORDER = _ORDER;
        REPORT = _REPORT;
        TIMEKEEPING = _TIMEKEEPING;
        cardVisa = _cardVisa;
        noti = _noti;
        revenueManager = _revenueManager;
        StaffAgentStore = _StaffAgentStore;
        // POINTS = _POINTS;
    }
    function createAgentIQR(address _agent) external onlyEnhanceSC returns (address) {
        require(MANAGEMENT != address(0) && ORDER != address(0) && REPORT != address(0) && TIMEKEEPING != address(0), //Points có thể để là address(0)
            "addresses of iqr can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentIQRContracts[_agent] == address(0), "Contract already exists");
        
        AgentIQR newContract = new AgentIQR(_agent,enhancedAgent,MANAGEMENT,ORDER,REPORT,TIMEKEEPING,revenueManager,StaffAgentStore);
        address contractAddr = address(newContract);
        
        agentIQRContracts[_agent] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentIQRCreated(_agent, contractAddr, block.timestamp);
        return contractAddr;
    }
    //admin gọi ngay sau gọi createAgent
    function setAgentIQR( address _agent)external onlyEnhanceSC{
        require(_agent != address(0), "Invalid agent");
        require(agentIQRContracts[_agent] != address(0), "Contract does not exist");
        AgentIQR agentIQR = AgentIQR(agentIQRContracts[_agent]);
        IQRContracts memory iqrScs = agentIQR.getIQRSCByAgent(_agent);
        agentIQR.set(_agent,iqrScs.Management,iqrScs.Order,iqrScs.Report,iqrScs.TimeKeeping,cardVisa,noti,iqrScs.StaffAgentStore);
    }
    //admin gọi ngay sau gọi createAgent nếu có dùng loyalty
    function setPointsIQRFactory(address _agent, address _Points) external onlyEnhanceSC {
        require(_Points != address(0),"Points contract not set yet");
        AgentIQR agentIQR = AgentIQR(agentIQRContracts[_agent]);
        agentIQR.setPointSC(_Points,_agent);
                // IPoint(_POINTS_PROXY).setManagementSC(iqr.Management);
        // IPoint(_POINTS_PROXY).setOrder(iqr.Order);

        POINTS = _Points;
    }
    function transferOwnerIQRContracts(address _agent)external onlyEnhanceSC {
        address agentIQR = agentIQRContracts[_agent];
        IQRContracts memory iqr = IAgentIQR(agentIQR).getIQRSCByAgent(_agent);
        IAgentIQR(agentIQR).transferOwnerIQR(_agent,iqr.Management,iqr.Order,iqr.Report,iqr.TimeKeeping);
    }
    function getAgentIQRContract(address _agent) external view returns (address) {
        return agentIQRContracts[_agent];
    }
    function getIQRSCByAgentFromFactory(address _agent) external view returns (IQRContracts memory) {
        address agentIqr = agentIQRContracts[_agent];
        IQRContracts memory iqrContracts = IAgentIQR(agentIqr).getIQRSCByAgent(_agent);
        return iqrContracts;
    }
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    
    function getVersion() external view returns (string memory) {
        return version;
    }
    
}


