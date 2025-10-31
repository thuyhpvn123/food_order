// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "./interfaces/IAgent.sol";

// // import "forge-std/console.sol";

// // ============================================================================
// // 6. AGENT LOYALTY CONTRACT (NON-UPGRADEABLE - Individual contracts)
// // ============================================================================
// contract AgentLoyalty is OwnableUpgradeable {
    
//     string public name = "Agent Loyalty Token";
//     string public symbol = "ALT";
//     uint8 public decimals = 18;
    
//     address public agent;
//     uint256 public totalSupply;
//     bool public frozen = false;
//     bool public redeemOnly = false;
//     uint256 public redeemDeadline;
//     bool public migrated = false;
    
//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;
    
//     // Additional tracking
//     uint256 public totalMinted;
//     uint256 public totalBurned;
//     uint256 public totalRedeemed;
//     address public enhancedAgentSC;
    
//     RewardTransaction[] public transactions;
//     mapping(address => uint256[]) public userTransactions;
//     address public migratedTo; // Track which contract we migrated to
    
//     // Migration tracking
//     mapping(address => bool) public userMigrated; // Track which users have migrated
//     uint256 public totalMigrated; // Total amount migrated out
    
    
//     // Store all token holders for migration
//     address[] public tokenHolders;
//     mapping(address => bool) public isTokenHolder;

//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);
//     event Mint(address indexed to, uint256 amount, string metadata);
//     event Burn(address indexed from, uint256 amount, string metadata);
//     event Redeem(address indexed user, uint256 amount, string reward);
//     event Frozen(uint256 timestamp);
//     event Unfrozen(uint256 timestamp);
//     event RedeemOnlyMode(uint256 deadline);
//     event TokensUnlocked(uint256 amount);
//     event TokensMigrated(address newContract, uint256 amount);
//      event MigrationInitiated(address indexed newContract, uint256 totalSupply, uint256 timestamp);
//     event UserBalanceMigrated(address indexed user, uint256 amount, address indexed newContract);
//     event MigrationCompleted(address indexed newContract, uint256 totalAmount, uint256 userCount);
//     constructor(address _agent,address _enhancedAgentSC) {
//         require(_agent != address(0), "Invalid agent address");
//         agent = _agent;
//         _transferOwnership(_agent);
//         enhancedAgentSC = _enhancedAgentSC;
//     }
    
//     modifier notFrozen() {
//         require(!frozen, "Contract is frozen");
//         _;
//     }
    
//     modifier canMint() {
//         require(!frozen && !redeemOnly && !migrated, "Cannot mint tokens");
//         _;
//     }
    
//     modifier notMigrated() {
//         require(!migrated, "Contract has been migrated");
//         _;
//     }
    
//     function mint(address _to, uint256 _amount, string memory _metadata) 
//         external 
//         onlyOwner 
//         canMint 
//     {
//         require(_to != address(0), "Cannot mint to zero address");
//         require(_amount > 0, "Amount must be greater than 0");
        
//         totalSupply += _amount;
//         totalMinted += _amount;
//         balanceOf[_to] += _amount;
        
//         // Record transaction
//         _recordTransaction(_to, _amount, "mint", _metadata);
//         tokenHolders.push(_to);
        
//         emit Mint(_to, _amount, _metadata);
//         emit Transfer(address(0), _to, _amount);
//     }
    
//     function burn(address _from, uint256 _amount, string memory _metadata) 
//         external 
//         onlyOwner 
//         notMigrated 
//     {
//         require(_from != address(0), "Cannot burn from zero address");
//         require(balanceOf[_from] >= _amount, "Insufficient balance");
        
//         balanceOf[_from] -= _amount;
//         totalSupply -= _amount;
//         totalBurned += _amount;
        
//         _recordTransaction(_from, _amount, "burn", _metadata);
        
//         emit Burn(_from, _amount, _metadata);
//         emit Transfer(_from, address(0), _amount);
//     }
    
//     function redeem(address _user, uint256 _amount, string memory _reward) 
//         external 
//         onlyOwner 
//         notMigrated 
//     {
//         require(_user != address(0), "Invalid user address");
//         require(balanceOf[_user] >= _amount, "Insufficient balance");
//         require(!frozen || redeemOnly, "Cannot redeem when frozen");
        
//         if (redeemOnly) {
//             require(block.timestamp <= redeemDeadline, "Redeem period expired");
//         }
        
//         balanceOf[_user] -= _amount;
//         totalSupply -= _amount;
//         totalRedeemed += _amount;
        
//         _recordTransaction(_user, _amount, "redeem", _reward);
        
//         emit Redeem(_user, _amount, _reward);
//         emit Transfer(_user, address(0), _amount);
//     }
    
//     function transfer(address _to, uint256 _amount) 
//         external 
//         notFrozen 
//         notMigrated 
//         returns (bool) 
//     {
//         return _transfer(msg.sender, _to, _amount);
//     }
    
//     function transferFrom(address _from, address _to, uint256 _amount) 
//         external 
//         notFrozen 
//         notMigrated 
//         returns (bool) 
//     {
//         require(allowance[_from][msg.sender] >= _amount, "Insufficient allowance");
        
//         allowance[_from][msg.sender] -= _amount;
//         return _transfer(_from, _to, _amount);
//     }
    
//     function _transfer(address _from, address _to, uint256 _amount) internal returns (bool) {
//         require(_from != address(0) && _to != address(0), "Invalid addresses");
//         require(balanceOf[_from] >= _amount, "Insufficient balance");
        
//         balanceOf[_from] -= _amount;
//         balanceOf[_to] += _amount;
        
//         emit Transfer(_from, _to, _amount);
//         return true;
//     }
    
//     function approve(address _spender, uint256 _amount) external returns (bool) {
//         allowance[msg.sender][_spender] = _amount;
//         emit Approval(msg.sender, _spender, _amount);
//         return true;
//     }
    
//     function freeze() external {
//         require(msg.sender == enhancedAgentSC || msg.sender == agent , "Unauthorized");
//         frozen = true;
//         emit Frozen(block.timestamp);
//     }
    
//     function unfreeze() external onlyOwner {
//         frozen = false;
//         emit Unfrozen(block.timestamp);
//     }
    
//     function setRedeemOnly(uint256 _days) external {
//         require(msg.sender == owner() || msg.sender == agent , "Unauthorized");
//         redeemOnly = true;
//         redeemDeadline = block.timestamp + (_days * 1 days);
//         emit RedeemOnlyMode(redeemDeadline);
//     }
//     modifier onlyAgentSC {
//         require(msg.sender == enhancedAgentSC , "only enhancedAgent contract can call");
//         _;
//     }
//     function unlockTokens() external onlyAgentSC returns (uint256) {
//         // require(msg.sender == owner() || msg.sender == agent , "Unauthorized");
//         require(frozen || redeemOnly, "Contract must be frozen or redeem-only");
        
//         uint256 contractBalance = balanceOf[address(this)];
//         if (contractBalance > 0) {
//             balanceOf[address(this)] = 0;
//             balanceOf[owner()] += contractBalance;
//             emit Transfer(address(this), owner(), contractBalance);
//         }
        
//         emit TokensUnlocked(contractBalance);
//         return contractBalance;
//     }
    
//     /**
//      * @dev Initiate migration to new contract (called by AgentManagement)
//      * This function is called on the OLD contract
//      */
//     function migrateTo(address _newContract) external onlyAgentSC returns (uint256) {
//         require(_newContract != address(0), "Invalid new contract");
//         require(!migrated, "Already migrated");
        
//         // Freeze the old contract
//         frozen = true;
//         migrated = true;
//         migratedTo = _newContract;
        
//         // Set redeem-only mode for 30 days
//         redeemOnly = true;
//         redeemDeadline = block.timestamp + (30 * 1 days);
        
//         // emit MigrationInitiated(_newContract, totalSupply, block.timestamp);
//         return totalSupply;
//     }   
//     /**
//      * @dev Get migration data for a specific user
//      * Called by new contract to verify migration
//      */
//     function getMigrationData(address _user) 
//         external 
//         view 
//         returns (
//             uint256 balance,
//             bool hasBalance,
//             bool alreadyMigrated
//         ) 
//     {
//         return (
//             balanceOf[_user],
//             balanceOf[_user] > 0,
//             userMigrated[_user]
//         );
//     }
    
//     /**
//      * @dev Mark user as migrated (called after successful migration)
//      * Only callable by the contract we migrated to
//      */
//     function markUserMigrated(address _user, uint256 _amount) external {
//         require(msg.sender == migratedTo, "Only new contract can mark migrated");
//         require(migrated, "Contract not in migration state");
//         require(balanceOf[_user] >= _amount, "Invalid migration amount");
        
//         userMigrated[_user] = true;
//         totalMigrated += _amount;
        
//         // Burn the migrated tokens from old contract
//         balanceOf[_user] -= _amount;
//         totalSupply -= _amount;
        
//         emit UserBalanceMigrated(_user, _amount, migratedTo);
//     }
    
//     /**
//      * @dev Get all token holders (for migration)
//      */
//     function getTokenHolders() external view returns (address[] memory) {
//         return tokenHolders;
//     }
    
//     /**
//      * @dev Get token holders with balances (for migration verification)
//      */
//     function getTokenHoldersWithBalances() 
//         external 
//         view 
//         returns (
//             address[] memory holders,
//             uint256[] memory balances
//         ) 
//     {
//         uint256 count = 0;
        
//         // Count holders with balance > 0
//         for (uint256 i = 0; i < tokenHolders.length; i++) {
//             if (balanceOf[tokenHolders[i]] > 0) {
//                 count++;
//             }
//         }
        
//         holders = new address[](count);
//         balances = new uint256[](count);
        
//         uint256 index = 0;
//         for (uint256 i = 0; i < tokenHolders.length; i++) {
//             if (balanceOf[tokenHolders[i]] > 0) {
//                 holders[index] = tokenHolders[i];
//                 balances[index] = balanceOf[tokenHolders[i]];
//                 index++;
//             }
//         }
//     }
    
//     // ========================================================================
//     // MIGRATION FUNCTIONS - PHASE 2: RECEIVE MIGRATION (NEW CONTRACT)
//     // ========================================================================
    
//     /**
//      * @dev Receive migrated tokens from old contract
//      * This function is called on the NEW contract
//      */
//     function receiveMigration(
//         address _oldContract,
//         address[] memory _users,
//         uint256[] memory _amounts
//     ) external onlyAgentSC returns (uint256 totalReceived) {
//         require(_oldContract != address(0), "Invalid old contract");
//         require(_users.length == _amounts.length, "Arrays length mismatch");
//         require(_users.length > 0, "No users to migrate");
        
//         // Verify old contract is in migrated state
//         AgentLoyalty oldContract = AgentLoyalty(_oldContract);
//         require(oldContract.migrated(), "Old contract not migrated");
//         require(oldContract.migratedTo() == address(this), "Migration target mismatch");
        
//         uint256 successCount = 0;
        
//         for (uint256 i = 0; i < _users.length; i++) {
//             address user = _users[i];
//             uint256 amount = _amounts[i];
            
//             if (amount == 0) continue;
            
//             // Verify user data from old contract
//             (, bool hasBalance, bool alreadyMigrated) = 
//                 oldContract.getMigrationData(user);
            
//             // Skip if already migrated or no balance
//             if (alreadyMigrated || !hasBalance ) continue;
            
//             // Mint tokens in new contract
//             totalSupply += amount;
//             totalMinted += amount;
//             balanceOf[user] += amount;
            
//             // Track token holder
//             if (!isTokenHolder[user]) {
//                 tokenHolders.push(user);
//                 isTokenHolder[user] = true;
//             }
            
//             // Mark as migrated in old contract
//             oldContract.markUserMigrated(user, amount);
            
//             totalReceived += amount;
//             successCount++;
            
//             emit Transfer(address(0), user, amount);
//             emit UserBalanceMigrated(user, amount, _oldContract);
//         }
        
//         emit MigrationCompleted(_oldContract, totalReceived, successCount);
//         return totalReceived;
//     }
    
//     /**
//      * @dev Batch migrate users (helper function to prepare migration data)
//      */
//     function prepareMigrationBatch(address _oldContract, uint256 _batchSize)
//         external
//         view
//         returns (
//             address[] memory users,
//             uint256[] memory amounts,
//             uint256 batchTotal
//         )
//     {
//         AgentLoyalty oldContract = AgentLoyalty(_oldContract);
        
//         (address[] memory allHolders, uint256[] memory allBalances) = 
//             oldContract.getTokenHoldersWithBalances();
        
//         uint256 actualSize = _batchSize > allHolders.length ? allHolders.length : _batchSize;
        
//         users = new address[](actualSize);
//         amounts = new uint256[](actualSize);
        
//         for (uint256 i = 0; i < actualSize; i++) {
//             users[i] = allHolders[i];
//             amounts[i] = allBalances[i];
//             batchTotal += allBalances[i];
//         }
//     }
    
//     // ========================================================================
//     // VIEW FUNCTIONS
//     // ========================================================================
    
    
    
//     function getMigrationInfo() external view returns (
//         bool _migrated,
//         address _migratedTo,
//         uint256 _totalMigrated,
//         uint256 _remainingSupply
//     ) {
//         return (migrated, migratedTo, totalMigrated, totalSupply);
//     }
    

//     function _recordTransaction(
//         address _user,
//         uint256 _amount,
//         string memory _type,
//         string memory _metadata
//     ) internal {
//         RewardTransaction memory transaction = RewardTransaction({
//             user: _user,
//             amount: _amount,
//             transactionType: _type,
//             timestamp: block.timestamp,
//             metadata: _metadata
//         });
        
//         transactions.push(transaction);
//         userTransactions[_user].push(transactions.length - 1);
//     }
    
//     // View functions
//     function isFrozen() external view returns (bool) {
//         return frozen;
//     }
    
//     function isRedeemOnly() external view returns (bool) {
//         return redeemOnly;
//     }
    
//     function isMigrated() external view returns (bool) {
//         return migrated;
//     }
    
//     function getRedeemDeadline() external view returns (uint256) {
//         return redeemDeadline;
//     }
    
//     function getTokenStats() external view returns (
//         uint256 _totalSupply,
//         uint256 _totalMinted,
//         uint256 _totalBurned,
//         uint256 _totalRedeemed,
//         uint256 _totalMigrated
//     ) {
//         return (totalSupply, totalMinted, totalBurned, totalRedeemed, totalMigrated);
//     }
        
//     function getUserTransactions(address _user) 
//         external 
//         view 
//         returns (uint256[] memory) 
//     {
//         return userTransactions[_user];
//     }
    
//     function getTransaction(uint256 _index) 
//         external 
//         view 
//         returns (RewardTransaction memory) 
//     {
//         require(_index < transactions.length, "Transaction not found");
//         return transactions[_index];
//     }
    
//     function getTotalTransactions() external view returns (uint256) {
//         return transactions.length;
//     }
// }
