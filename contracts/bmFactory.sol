// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";
import {BranchManagement} from "./branchManager.sol";

contract BMFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => address) public agentBranchManagement;
    address public enhancedAgent;
    address public BRANCH_MANAGEMENT_IMP;
    address public HISTORY_TRACKING_IMP;
    address public freeGasSc;
    address public StaffAgentStore;
    address public iqrFactory;
    uint256[49] private __gap;

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
    function setBranchManagerSC(
        address _BRANCH_MANAGEMENT_IMP,
        address _HISTORY_TRACKING_IMP,
        // address _freeGasSc,
        address _StaffAgentStore,
        address _iqrFactory,
        address _enhancedAgent
    )external onlyOwner {
        if(_BRANCH_MANAGEMENT_IMP != address(0)){BRANCH_MANAGEMENT_IMP = _BRANCH_MANAGEMENT_IMP;} 
        if(_HISTORY_TRACKING_IMP != address(0)){HISTORY_TRACKING_IMP = _HISTORY_TRACKING_IMP;} 
        // if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(_iqrFactory != address(0)){iqrFactory = _iqrFactory;}
        if(_StaffAgentStore != address(0)){StaffAgentStore = _StaffAgentStore;}
        // IIQRFactory(iqrFactory).setFreeGasSC(_freeGasSc);
        if(_enhancedAgent != address(0)){enhancedAgent = _enhancedAgent;}
    }
    
    function createBranchManagement(address _agent) external onlyEnhanceSC returns (address) {
        require(_agent != address(0), "Invalid agent");
        require(agentBranchManagement[_agent] == address(0), "BranchManagement already exists");
        require(HISTORY_TRACKING_IMP != address(0), "HISTORY_TRACKING not set yet");
        // Deploy BranchManagement contract
        BranchManagement branchMgmt = new BranchManagement();
        ERC1967Proxy BRANCH_MANAGEMENT_PROXY = new ERC1967Proxy(
            address(BRANCH_MANAGEMENT_IMP),
            abi.encodeWithSelector(IBranchManagement.initialize.selector,
            _agent,HISTORY_TRACKING_IMP,freeGasSc)
        );

        address contractAddr = address(BRANCH_MANAGEMENT_PROXY);
        agentBranchManagement[_agent] = contractAddr;
        IBranchManagement(contractAddr).setStaffAgentStore(StaffAgentStore);
        IBranchManagement(contractAddr).setIqrFactorySC(iqrFactory);
        IStaffAgentStore(StaffAgentStore).setBranchManagement(contractAddr);
        address[] memory iqrAdds= new address[](1);
        iqrAdds[0] = address(BRANCH_MANAGEMENT_PROXY);
        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(_agent,iqrAdds);
            IFreeGas(freeGasSc).registerSCAdmin(address(BRANCH_MANAGEMENT_PROXY),true);
        }
        return contractAddr;
    }
    function addManagerMainBranch(address _branchManagerProxy,address _agent, uint256[] memory branchIds)external onlyEnhanceSC {
        IBranchManagement(_branchManagerProxy).AddAndUpdateManager(_agent,"main owner","phone","image",true,branchIds,true,true,true,true);

    }
    function getBranchManagement(address _agent) external view returns (address) {
        return agentBranchManagement[_agent];
    }
}


