// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import {AgentMeos} from "./agentMeos.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";
contract MeosFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    
    mapping(address =>mapping(uint => address)) public agentMeosContracts;
    mapping(address => address) public agentBranchManagement;
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
    address public BRANCH_MANAGEMENT_IMP;
    address public HISTORY_TRACKING_IMP;
    address public freeGasSc;
    uint256[49] private __gap;
    event AgentMeosCreated(address indexed agent,uint indexed branchId ,address indexed contractAddr, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setMeos(
        address _MANAGEMENT, //implement ,not proxy
        address _ORDER,
        address _REPORT,
        address _TIMEKEEPING,
        address _cardVisa,
        address _noti,
        address _revenueManager, //proxy dùng cho từng agent
        address _StaffAgentStore, //proxy dùng cho tất cả agent
        // address _POINTS
        address _BRANCH_MANAGEMENT_IMP,
        address _HISTORY_TRACKING_IMP,
        address _freeGasSc
    )external onlyOwner {
        if(_MANAGEMENT != address(0)){MANAGEMENT = _MANAGEMENT;} 
        if(_ORDER != address(0)){ORDER = _ORDER;} 
        if(_REPORT != address(0)){REPORT = _REPORT;} 
        if(_TIMEKEEPING != address(0)){TIMEKEEPING = _TIMEKEEPING;} 
        if(_cardVisa != address(0)){cardVisa = _cardVisa;} 
        if(_noti != address(0)){noti = _noti;} 
        if(_revenueManager != address(0)){revenueManager = _revenueManager;} 
        if(_BRANCH_MANAGEMENT_IMP != address(0)){BRANCH_MANAGEMENT_IMP = _BRANCH_MANAGEMENT_IMP;} 
        if(_HISTORY_TRACKING_IMP != address(0)){HISTORY_TRACKING_IMP = _HISTORY_TRACKING_IMP;} 
        if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(_StaffAgentStore != address(0)){StaffAgentStore = _StaffAgentStore;}  
        // POINTS = _POINTS;
        
    }
    function createAgentMeos(address _agent, uint _branchId) external onlyEnhanceSC returns (address) {
        require(MANAGEMENT != address(0) && ORDER != address(0) && REPORT != address(0) && TIMEKEEPING != address(0), //Points có thể để là address(0)
            "addresses of iqr can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentMeosContracts[_agent][_branchId] == address(0), "Contract already exists");
        
        AgentMeos newContract = new AgentMeos(_agent,enhancedAgent,MANAGEMENT,ORDER,REPORT,TIMEKEEPING,revenueManager,StaffAgentStore,_branchId);
        MeosContracts memory iqr = newContract.getMeosSCByAgent(_agent,_branchId);
        address[] memory iqrAdds= new address[](4);
        iqrAdds[0] = iqr.Management;
        iqrAdds[1] = iqr.Order;
        iqrAdds[2] = iqr.Report;
        iqrAdds[3] = iqr.TimeKeeping;

        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(_agent,iqrAdds);
        }
        address contractAddr = address(newContract);
        
        agentMeosContracts[_agent][_branchId] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentMeosCreated(_agent,_branchId, contractAddr, block.timestamp);
        return contractAddr;
    }
    //admin gọi ngay sau gọi createAgent
    function setAgentIQR( address _agent, uint _branchId, address _branchManagement)external onlyEnhanceSC{
        require(_agent != address(0), "Invalid agent");
        require(agentMeosContracts[_agent][_branchId] != address(0), "Contract does not exist");
        AgentMeos agentIQR = AgentMeos(agentMeosContracts[_agent][_branchId]);
        MeosContracts memory iqrScs = agentIQR.getMeosSCByAgent(_agent,_branchId);
        agentIQR.set(_agent,iqrScs.Management,iqrScs.Order,iqrScs.Report,iqrScs.TimeKeeping,cardVisa,noti,iqrScs.StaffAgentStore,_branchManagement);
    }
    //admin gọi ngay sau gọi createAgent nếu có dùng loyalty
    function setPointsIQRFactory(address _agent, address _Points, uint _branchId) external onlyEnhanceSC {
        require(_Points != address(0),"Points contract not set yet");
        AgentMeos agentIQR = AgentMeos(agentMeosContracts[_agent][_branchId]);
        agentIQR.setPointSC(_Points,_agent,_branchId);

        POINTS = _Points;
    }
    function transferOwnerMeosContracts(address _agent, uint _branchId)external onlyEnhanceSC {
        address agentIQR = agentMeosContracts[_agent][_branchId];
        MeosContracts memory meos = IAgentMeos(agentIQR).getMeosSCByAgent(_agent,_branchId);
        IAgentIQR(agentIQR).transferOwnerIQR(_agent,meos.Management,meos.Order,meos.Report,meos.TimeKeeping);
    }
    function getAgentMEOSContract(address _agent, uint _branchId) external view returns (address) {
        return agentMeosContracts[_agent][_branchId];
    }
    function getIQRSCByAgentFromFactory(address _agent, uint _branchId) external view returns (MeosContracts memory) {
        address agentIqr = agentMeosContracts[_agent][_branchId];
        MeosContracts memory meosContracts = IAgentMeos(agentIqr).getMeosSCByAgent(_agent,_branchId);
        return meosContracts;
    }
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs) {
        managementScs = new address[](_branchIds.length);
        for(uint i=0; i< _branchIds.length;i++){
            address agentMeos = agentMeosContracts[_agent][_branchIds[i]];
            MeosContracts memory iqrContracts = IAgentMeos(agentMeos).getMeosSCByAgent(_agent,_branchIds[i]);
            managementScs[i] = iqrContracts.Management;
        }
    }
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    
    // function createBranchManagement(address _agent,uint[] memory branchIds) external onlyEnhanceSC returns (address) {
    //     require(_agent != address(0), "Invalid agent");
    //     require(agentBranchManagement[_agent] == address(0), "BranchManagement already exists");
    //     require(HISTORY_TRACKING_IMP != address(0), "HISTORY_TRACKING not set yet");
    //     // Deploy BranchManagement contract
    //     // BranchManagement branchMgmt = new BranchManagement();
    //     ERC1967Proxy BRANCH_MANAGEMENT_PROXY = new ERC1967Proxy(
    //         address(BRANCH_MANAGEMENT_IMP),
    //         abi.encodeWithSelector(IBranchManagement.initialize.selector,
    //         _agent,HISTORY_TRACKING_IMP,freeGasSc)
    //     );

    //     address contractAddr = address(BRANCH_MANAGEMENT_PROXY);
    //     agentBranchManagement[_agent] = contractAddr;
    //     IBranchManagement(contractAddr).setStaffAgentStore(StaffAgentStore);
    //     IBranchManagement(contractAddr).setIqrFactorySC(address(this));
    //     IStaffAgentStore(StaffAgentStore).setBranchManagement(contractAddr);
    //     address[] memory iqrAdds= new address[](1);
    //     iqrAdds[0] = address(BRANCH_MANAGEMENT_PROXY);
    //     if(freeGasSc != address(0)){
    //         IFreeGas(freeGasSc).AddSC(_agent,iqrAdds);
    //         IFreeGas(freeGasSc).registerSCAdmin(address(BRANCH_MANAGEMENT_PROXY),true);
    //     }
    //     return contractAddr;
    // }
    // function addManagerMainBranch(address _branchManagerProxy,address _agent, uint256[] memory branchIds)external onlyEnhanceSC {
    //     IBranchManagement(_branchManagerProxy).AddAndUpdateManager(_agent,"main owner","phone","image",true,branchIds,true,true,true,true);

    // }
    // function getBranchManagement(address _agent) external view returns (address) {
    //     return agentBranchManagement[_agent];
    // }
}


