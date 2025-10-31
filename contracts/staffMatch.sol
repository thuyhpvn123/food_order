// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
contract StaffAgentStore is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address =>bool) public isManagement;
    uint256[50] private __gap;
        constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the contract (replaces constructor)
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyManagement {
        require(isManagement[msg.sender], "Only management can call this function");
        _;
    }
    mapping(address => address) public mUserToAgent;
    address public iqrFactory;
    address public enhancedAgent;

    function setManagement(address _management) external  {
        isManagement[ _management] = true;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setIqrFactory(address _iqrFactory) external onlyOwner {
        iqrFactory = _iqrFactory;
    }
    function setAgent(address user, address agent) onlyManagement external{
        //kiểm tra agent có tồn tại không
        require((CheckAgentCreated(agent)),"agent not exist");
        mUserToAgent[user] = agent;
    }
    function CheckAgentCreated(address _agent)public view returns(bool){
        return IEnhancedAgent(enhancedAgent).CheckAgentExisted(_agent);
    }
    function checkUserAgentExist(address user) public view returns(bool){
        return (mUserToAgent[user] != address(0));
    }
    function getUserAgetSCs(address user) external returns(IQRContracts memory iQRContracts){
        require(iqrFactory != address(0),"iqrFactory not set yet");
        address agent = mUserToAgent[user];
        if (agent != address(0)) {
            address iqrAgentAdd = IIQRFactory(iqrFactory).getAgentIQRContract(agent);
            iQRContracts = IAgentIQR(iqrAgentAdd).getIQRSCByAgent(agent);
        }
    }
}