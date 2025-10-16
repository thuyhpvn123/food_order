// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RestaurantLoyaltySystem
 * @dev Hệ thống tích điểm khách hàng thân thiết cho nhà hàng trên MetaNode Blockchain
 */
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IPoint.sol";
import "./interfaces/IManagement.sol";

contract RestaurantLoyaltySystem is
    Initializable, 
    ReentrancyGuardUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    UUPSUpgradeable  
{
   
    // ============ STATE VARIABLES ============
    IManagement public MANAGEMENT;
    uint256 public exchangeRate;                   // Tỷ giá: X VND = 1 điểm
    uint256 public pointExpiryPeriod;              // Thời gian hết hạn điểm (giây)
    uint256 public totalPointsIssued;              // Tổng điểm đã phát hành
    uint256 public totalPointsRedeemed;            // Tổng điểm đã đổi
    uint256 public sessionDuration;                // Thời gian lưu phiên (giây)
    
    // Counters
    uint256 private transactionCounter;
    uint256 private eventCounter;
    uint256 private rewardCounter;
    uint256 private issuanceCounter;
    uint256 private requestCounter;
    
    // Mappings
    mapping(address => Member) public members;
    mapping(string => address) public memberIdToAddress;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => Event) public events;
    mapping(uint256 => Reward) public rewards;
    mapping(Tier => TierConfig) public tierConfigs;
    mapping(uint256 => PointIssuance) public issuances;
    mapping(uint256 => ManualRequest) public manualRequests;
    mapping(address => uint256[]) public memberTransactions;
    mapping(address => uint256) public staffDailyRequests; // Giới hạn yêu cầu/ngày
    mapping(address => uint256) public lastRequestDate;
    mapping(string => bool) public processedInvoices; // Chống trùng hóa đơn
    bytes32 constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

    // ============ EVENTS ============
    
    event MemberRegistered(address indexed wallet, string memberId, uint256 timestamp);
    event PointsEarned(address indexed member, uint256 points, string invoiceId, uint256 timestamp);
    event PointsRedeemed(address indexed member, uint256 points, uint256 rewardId, uint256 timestamp);
    event TierUpdated(address indexed member, Tier oldTier, Tier newTier, uint256 timestamp);
    event PointsExpired(address indexed member, uint256 points, uint256 timestamp);
    event EventCreated(uint256 indexed eventId, string name, uint256 startTime, uint256 endTime);
    event RewardCreated(uint256 indexed rewardId, string name, uint256 pointsCost);
    event TransactionCreated(uint256 indexed txId, address indexed member, TransactionType txType, int256 points);
    event MemberLocked(address indexed member, address indexed admin, string reason, uint256 timestamp);
    event MemberUnlocked(address indexed member, address indexed admin, uint256 timestamp);
    event PointsIssued(uint256 indexed issuanceId, uint256 amount, address indexed issuedBy, uint256 timestamp);
    event ManualRequestCreated(uint256 indexed requestId, address indexed member, address indexed staff, uint256 timestamp);
    event ManualRequestProcessed(uint256 indexed requestId, bool approved, address indexed admin, uint256 timestamp);
    event PointsRefunded(address indexed member, uint256 points, string invoiceId, string reason, uint256 timestamp);
    event RoleGranted(address indexed account, Role role, address indexed admin);
    event RoleRevoked(address indexed account, address indexed admin);
    
    // ============ MODIFIERS ============
        
    modifier onlyAdmin() {
        require(MANAGEMENT.hasRole(ROLE_ADMIN, msg.sender) , "Only admin");
        _;
    }
    
    modifier onlyStaffOrAdmin() {
        require(MANAGEMENT.isStaff(msg.sender), "Only staff or admin");
        _;
    }
    modifier memberExists(address _member) {
        require(members[_member].isActive, "Member not found");
        _;
    }
    
    modifier notLocked(address _member) {
        require(!members[_member].isLocked, "Account is locked");
        _;
    }
    uint256[10] private __gap;

    constructor() {
        _disableInitializers();
    }
    function initialize() public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        exchangeRate = 10000; // 10,000 VND = 1 điểm
        pointExpiryPeriod = 365 days; // 12 tháng
        sessionDuration = 30 days; // 30 ngày
        
        // Thiết lập cấu hình hạng mặc định
        tierConfigs[Tier.Silver] = TierConfig({
            pointsRequired: 1000,
            multiplier: 120, // 1.2x
            validityPeriod: 180 days // 6 tháng
        });
        
        tierConfigs[Tier.Gold] = TierConfig({
            pointsRequired: 3000,
            multiplier: 150, // 1.5x
            validityPeriod: 365 days // 12 tháng
        });
        
        tierConfigs[Tier.Platinum] = TierConfig({
            pointsRequired: 7000,
            multiplier: 200, // 2x
            validityPeriod: 365 days // 12 tháng
        });

    }    

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ============ MEMBER FUNCTIONS ============
    
    /**
     * @dev Đăng ký thành viên mới
     */
    function setManagementSC(address _management)external onlyOwner {
        MANAGEMENT = IManagement(_management);
    } 
    function registerMember(
        string memory _memberId,
        string memory _phoneNumber,
        string memory _fullName
    ) external {
        require(bytes(_memberId).length >= 8 && bytes(_memberId).length <= 12, "Invalid member ID length");
        require(!members[msg.sender].isActive, "Already registered");
        require(memberIdToAddress[_memberId] == address(0), "Member ID already exists");
        
        members[msg.sender] = Member({
            memberId: _memberId,
            walletAddress: msg.sender,
            totalPoints: 0,
            lifetimePoints: 0,
            totalSpent: 0,
            tier: Tier.None,
            tierUpdatedAt: block.timestamp,
            lastActivityAt: block.timestamp,
            isActive: true,
            isLocked: false,
            phoneNumber: _phoneNumber,
            fullName: _fullName
        });
        
        memberIdToAddress[_memberId] = msg.sender;
        
        emit MemberRegistered(msg.sender, _memberId, block.timestamp);
    }
    
    /**
     * @dev Tích điểm tự động (khi thanh toán)
     */
    function earnPoints(
        address _member,
        uint256 _amount,
        string memory _invoiceId
    ) external  memberExists(_member) notLocked(_member) {
        require(!processedInvoices[_invoiceId], "Invoice already processed");
        require(_amount > 0, "Invalid amount");
        
        Member storage member = members[_member];
        
        // Tính điểm dựa trên số tiền và tỷ giá
        uint256 basePoints = _amount / exchangeRate;
        
        // Áp dụng hệ số hạng thành viên
        uint256 tierMultiplier = _getTierMultiplier(member.tier);
        uint256 points = (basePoints * tierMultiplier) / 100;
        
        // Kiểm tra sự kiện đang diễn ra
        uint256 activeEventId = _getActiveEvent(member.tier);
        if (activeEventId > 0) {
            Event storage evt = events[activeEventId];
            uint256 eventPoints = (points * evt.multiplier) / 100;
            
            // Áp dụng giới hạn nếu có
            if (evt.maxPointsPerInvoice > 0 && eventPoints > evt.maxPointsPerInvoice) {
                eventPoints = evt.maxPointsPerInvoice;
            }
            
            points = eventPoints;
        }
        
        // Cập nhật điểm thành viên
        member.totalPoints += points;
        member.lifetimePoints += points;
        member.totalSpent += _amount;
        member.lastActivityAt = block.timestamp;
        
        // Cập nhật hạng nếu đạt điều kiện
        _updateMemberTier(_member);
        
        // Ghi nhận giao dịch
        _createTransaction(
            _member,
            TransactionType.Earn,
            int256(points),
            _amount,
            _invoiceId,
            "",
            activeEventId
        );
        
        // Đánh dấu hóa đơn đã xử lý
        processedInvoices[_invoiceId] = true;
        
        totalPointsIssued += points;
        
        emit PointsEarned(_member, points, _invoiceId, block.timestamp);
    }
    
    /**
     * @dev Đổi điểm lấy quà
     */
    function redeemPoints(uint256 _rewardId) external memberExists(msg.sender) notLocked(msg.sender) {
        Member storage member = members[msg.sender];
        Reward storage reward = rewards[_rewardId];
        
        require(reward.isActive, "Reward not active");
        require(reward.quantity > 0, "Reward out of stock");
        require(member.totalPoints >= reward.pointsCost, "Insufficient points");
        require(member.tier >= reward.minTier, "Tier requirement not met");
        
        // Trừ điểm
        member.totalPoints -= reward.pointsCost;
        member.lastActivityAt = block.timestamp;
        reward.quantity -= 1;
        
        // Ghi nhận giao dịch
        _createTransaction(
            msg.sender,
            TransactionType.Redeem,
            -int256(reward.pointsCost),
            0,
            "",
            reward.name,
            0
        );
        
        totalPointsRedeemed += reward.pointsCost;
        
        emit PointsRedeemed(msg.sender, reward.pointsCost, _rewardId, block.timestamp);
    }
    
    // ============ STAFF FUNCTIONS ============
    
    /**
     * @dev Nhân viên tạo yêu cầu tích điểm thủ công
     */
    function createManualRequest(
        address _member,
        string memory _invoiceId,
        uint256 _amount,
        string memory _note
    ) external onlyStaffOrAdmin returns (uint256) {
        require(members[_member].isActive, "Member not found");
        require(!processedInvoices[_invoiceId], "Invoice already processed");
        
        // Kiểm tra giới hạn yêu cầu hàng ngày
        if (block.timestamp / 1 days > lastRequestDate[msg.sender] / 1 days) {
            staffDailyRequests[msg.sender] = 0;
            lastRequestDate[msg.sender] = block.timestamp;
        }
        
        require(staffDailyRequests[msg.sender] < 50, "Daily request limit reached");
        
        uint256 pointsToEarn = _amount / exchangeRate;
        
        requestCounter++;
        manualRequests[requestCounter] = ManualRequest({
            id: requestCounter,
            member: _member,
            invoiceId: _invoiceId,
            amount: _amount,
            pointsToEarn: pointsToEarn,
            requestedBy: msg.sender,
            requestTime: block.timestamp,
            status: RequestStatus.Pending,
            approvedBy: address(0),
            approvedTime: 0,
            rejectReason: "",
            note: _note
        });
        
        staffDailyRequests[msg.sender]++;
        
        emit ManualRequestCreated(requestCounter, _member, msg.sender, block.timestamp);
        
        return requestCounter;
    }
    
    /**
     * @dev Nhân viên quét QR và trừ điểm cho khách
     */
    function redeemPointsForCustomer(
        address _member,
        uint256 _points,
        string memory _note
    ) external onlyStaffOrAdmin memberExists(_member) notLocked(_member) {
        Member storage member = members[_member];
        
        require(member.totalPoints >= _points, "Insufficient points");
        
        member.totalPoints -= _points;
        member.lastActivityAt = block.timestamp;
        
        _createTransaction(
            _member,
            TransactionType.Redeem,
            -int256(_points),
            0,
            "",
            _note,
            0
        );
        
        totalPointsRedeemed += _points;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Phát hành Xu (tạo điểm mới cho hệ thống)
     */
    function issuePoints(uint256 _amount, string memory _note) external onlyAdmin {
        require(_amount > 0, "Invalid amount");
        
        issuanceCounter++;
        issuances[issuanceCounter] = PointIssuance({
            id: issuanceCounter,
            amount: _amount,
            issuedBy: msg.sender,
            timestamp: block.timestamp,
            note: _note,
            status: IssuanceStatus.Success
        });
        
        emit PointsIssued(issuanceCounter, _amount, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Duyệt yêu cầu tích điểm thủ công
     */
    function approveManualRequest(uint256 _requestId) external onlyAdmin {
        ManualRequest storage request = manualRequests[_requestId];
        
        require(request.status == RequestStatus.Pending, "Request already processed");
        require(!processedInvoices[request.invoiceId], "Invoice already processed");
        
        Member storage member = members[request.member];
        
        // Tính điểm với hệ số hạng
        uint256 tierMultiplier = _getTierMultiplier(member.tier);
        uint256 points = (request.pointsToEarn * tierMultiplier) / 100;
        
        // Cộng điểm
        member.totalPoints += points;
        member.lifetimePoints += points;
        member.totalSpent += request.amount;
        member.lastActivityAt = block.timestamp;
        
        // Cập nhật yêu cầu
        request.status = RequestStatus.Approved;
        request.approvedBy = msg.sender;
        request.approvedTime = block.timestamp;
        
        // Đánh dấu hóa đơn
        processedInvoices[request.invoiceId] = true;
        
        // Cập nhật hạng
        _updateMemberTier(request.member);
        
        // Tạo giao dịch
        _createTransaction(
            request.member,
            TransactionType.Earn,
            int256(points),
            request.amount,
            request.invoiceId,
            request.note,
            0
        );
        
        totalPointsIssued += points;
        
        emit ManualRequestProcessed(_requestId, true, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Từ chối yêu cầu tích điểm thủ công
     */
    function rejectManualRequest(uint256 _requestId, string memory _reason) external onlyAdmin {
        ManualRequest storage request = manualRequests[_requestId];
        
        require(request.status == RequestStatus.Pending, "Request already processed");
        
        request.status = RequestStatus.Rejected;
        request.approvedBy = msg.sender;
        request.approvedTime = block.timestamp;
        request.rejectReason = _reason;
        
        emit ManualRequestProcessed(_requestId, false, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Điều chỉnh điểm thủ công
     */
    function adjustPoints(
        address _member,
        int256 _points,
        string memory _reason
    ) external onlyAdmin memberExists(_member) {
        require(bytes(_reason).length > 0, "Reason required");
        
        Member storage member = members[_member];
        
        if (_points > 0) {
            member.totalPoints += uint256(_points);
            member.lifetimePoints += uint256(_points);
        } else {
            uint256 absPoints = uint256(-_points);
            require(member.totalPoints >= absPoints, "Insufficient points");
            member.totalPoints -= absPoints;
        }
        
        member.lastActivityAt = block.timestamp;
        
        _createTransaction(
            _member,
            TransactionType.ManualAdjust,
            _points,
            0,
            "",
            _reason,
            0
        );
        
        _updateMemberTier(_member);
    }
    
    /**
     * @dev Hoàn điểm khi khách hủy/trả món
     */
    function refundPoints(
        address _member,
        string memory _invoiceId,
        string memory _reason
    ) external onlyAdmin memberExists(_member) {
        require(processedInvoices[_invoiceId], "Invoice not found");
        
        // Tìm giao dịch tích điểm gốc
        uint256[] memory txIds = memberTransactions[_member];
        uint256 pointsToRefund = 0;
        
        for (uint256 i = 0; i < txIds.length; i++) {
            Transaction storage tx = transactions[txIds[i]];
            if (
                keccak256(bytes(tx.invoiceId)) == keccak256(bytes(_invoiceId)) &&
                tx.txType == TransactionType.Earn
            ) {
                pointsToRefund = uint256(tx.points);
                break;
            }
        }
        
        require(pointsToRefund > 0, "Transaction not found");
        
        Member storage member = members[_member];
        require(member.totalPoints >= pointsToRefund, "Insufficient points");
        
        // Trừ điểm
        member.totalPoints -= pointsToRefund;
        if (member.lifetimePoints >= pointsToRefund) {
            member.lifetimePoints -= pointsToRefund;
        }
        
        // Tạo giao dịch hoàn điểm
        _createTransaction(
            _member,
            TransactionType.Refund,
            -int256(pointsToRefund),
            0,
            _invoiceId,
            _reason,
            0
        );
        
        // Xóa đánh dấu hóa đơn
        processedInvoices[_invoiceId] = false;
        
        emit PointsRefunded(_member, pointsToRefund, _invoiceId, _reason, block.timestamp);
    }
    
    /**
     * @dev Khóa tài khoản thành viên
     */
    function lockMember(address _member, string memory _reason) external onlyAdmin memberExists(_member) {
        members[_member].isLocked = true;
        emit MemberLocked(_member, msg.sender, _reason, block.timestamp);
    }
    
    /**
     * @dev Mở khóa tài khoản thành viên
     */
    function unlockMember(address _member) external onlyAdmin memberExists(_member) {
        members[_member].isLocked = false;
        emit MemberUnlocked(_member, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Tạo sự kiện/chương trình khuyến mãi
     */
    function createEvent(
        string memory _name,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _multiplier,
        Tier _minTier,
        uint256 _maxPointsPerInvoice,
        uint256 _maxPointsPerMember,
        string memory _description
    ) external onlyAdmin returns (uint256) {
        require(_startTime < _endTime, "Invalid time range");
        require(_multiplier >= 100, "Multiplier must be >= 1x");
        
        eventCounter++;
        events[eventCounter] = Event({
            id: eventCounter,
            name: _name,
            startTime: _startTime,
            endTime: _endTime,
            multiplier: _multiplier,
            minTier: _minTier,
            isActive: true,
            maxPointsPerInvoice: _maxPointsPerInvoice,
            maxPointsPerMember: _maxPointsPerMember,
            description: _description
        });
        
        emit EventCreated(eventCounter, _name, _startTime, _endTime);
        
        return eventCounter;
    }
    
    /**
     * @dev Tạo quà tặng
     */
    function createReward(
        string memory _name,
        uint256 _pointsCost,
        Tier _minTier,
        uint256 _quantity,
        string memory _description
    ) external onlyAdmin returns (uint256) {
        require(_pointsCost > 0, "Invalid points cost");
        
        rewardCounter++;
        rewards[rewardCounter] = Reward({
            id: rewardCounter,
            name: _name,
            pointsCost: _pointsCost,
            minTier: _minTier,
            quantity: _quantity,
            isActive: true,
            description: _description
        });
        
        emit RewardCreated(rewardCounter, _name, _pointsCost);
        
        return rewardCounter;
    }
    
    /**
     * @dev Cập nhật cấu hình hạng thành viên
     */
    function updateTierConfig(
        Tier _tier,
        uint256 _pointsRequired,
        uint256 _multiplier,
        uint256 _validityPeriod
    ) external onlyAdmin {
        require(_tier != Tier.None, "Invalid tier");
        
        tierConfigs[_tier] = TierConfig({
            pointsRequired: _pointsRequired,
            multiplier: _multiplier,
            validityPeriod: _validityPeriod
        });
    }
      
    /**
     * @dev Cập nhật tỷ giá quy đổi
     */
    function updateExchangeRate(uint256 _newRate) external onlyAdmin {
        require(_newRate > 0, "Invalid rate");
        exchangeRate = _newRate;
    }
    
    /**
     * @dev Cập nhật thời gian hết hạn điểm
     */
    function updatePointExpiryPeriod(uint256 _newPeriod) external onlyAdmin {
        pointExpiryPeriod = _newPeriod;
    }
    
    /**
     * @dev Cập nhật thời gian lưu phiên
     */
    function updateSessionDuration(uint256 _newDuration) external onlyAdmin {
        sessionDuration = _newDuration;
    }
    
    /**
     * @dev Bật/tắt sự kiện
     */
    function toggleEvent(uint256 _eventId, bool _isActive) external onlyAdmin {
        require(events[_eventId].id > 0, "Event not found");
        events[_eventId].isActive = _isActive;
    }
    
    /**
     * @dev Bật/tắt quà tặng
     */
    function toggleReward(uint256 _rewardId, bool _isActive) external onlyAdmin {
        require(rewards[_rewardId].id > 0, "Reward not found");
        rewards[_rewardId].isActive = _isActive;
    }
    
    /**
     * @dev Cập nhật số lượng quà tặng
     */
    function updateRewardQuantity(uint256 _rewardId, uint256 _newQuantity) external onlyAdmin {
        require(rewards[_rewardId].id > 0, "Reward not found");
        rewards[_rewardId].quantity = _newQuantity;
    }
    
    /**
     * @dev Xử lý điểm hết hạn (gọi định kỳ bởi backend)
     */
    function expirePoints(address _member) external onlyAdmin memberExists(_member) {
        Member storage member = members[_member];
        
        // Kiểm tra thời gian không hoạt động
        if (block.timestamp - member.lastActivityAt > pointExpiryPeriod) {
            uint256 expiredPoints = member.totalPoints;
            
            if (expiredPoints > 0) {
                member.totalPoints = 0;
                
                _createTransaction(
                    _member,
                    TransactionType.Expire,
                    -int256(expiredPoints),
                    0,
                    "",
                    "Points expired due to inactivity",
                    0
                );
                
                emit PointsExpired(_member, expiredPoints, block.timestamp);
            }
            
            // Hạ hạng về None
            if (member.tier != Tier.None) {
                Tier oldTier = member.tier;
                member.tier = Tier.None;
                member.tierUpdatedAt = block.timestamp;
                emit TierUpdated(_member, oldTier, Tier.None, block.timestamp);
            }
        }
    }
    
    /**
     * @dev Duyệt hàng loạt yêu cầu tích điểm
     */
    function batchApproveRequests(uint256[] calldata _requestIds) external onlyAdmin {
        for (uint256 i = 0; i < _requestIds.length; i++) {
            uint256 requestId = _requestIds[i];
            ManualRequest storage request = manualRequests[requestId];
            
            if (
                request.status == RequestStatus.Pending && 
                !processedInvoices[request.invoiceId]
            ) {
                Member storage member = members[request.member];
                
                uint256 tierMultiplier = _getTierMultiplier(member.tier);
                uint256 points = (request.pointsToEarn * tierMultiplier) / 100;
                
                member.totalPoints += points;
                member.lifetimePoints += points;
                member.totalSpent += request.amount;
                member.lastActivityAt = block.timestamp;
                
                request.status = RequestStatus.Approved;
                request.approvedBy = msg.sender;
                request.approvedTime = block.timestamp;
                
                processedInvoices[request.invoiceId] = true;
                
                _updateMemberTier(request.member);
                
                _createTransaction(
                    request.member,
                    TransactionType.Earn,
                    int256(points),
                    request.amount,
                    request.invoiceId,
                    request.note,
                    0
                );
                
                totalPointsIssued += points;
                
                emit ManualRequestProcessed(requestId, true, msg.sender, block.timestamp);
            }
        }
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Tạo giao dịch mới
     */
    function _createTransaction(
        address _member,
        TransactionType _txType,
        int256 _points,
        uint256 _amount,
        string memory _invoiceId,
        string memory _note,
        uint256 _eventId
    ) internal {
        transactionCounter++;
        
        transactions[transactionCounter] = Transaction({
            id: transactionCounter,
            member: _member,
            txType: _txType,
            points: _points,
            amount: _amount,
            invoiceId: _invoiceId,
            processedBy: msg.sender,
            timestamp: block.timestamp,
            note: _note,
            eventId: _eventId,
            status: PointTransactionStatus.Completed
        });
        
        memberTransactions[_member].push(transactionCounter);
        
        emit TransactionCreated(transactionCounter, _member, _txType, _points);
    }
    
    /**
     * @dev Cập nhật hạng thành viên
     */
    function _updateMemberTier(address _member) internal {
        Member storage member = members[_member];
        Tier oldTier = member.tier;
        Tier newTier = _calculateTier(member.lifetimePoints);
        
        if (newTier != oldTier) {
            member.tier = newTier;
            member.tierUpdatedAt = block.timestamp;
            
            emit TierUpdated(_member, oldTier, newTier, block.timestamp);
        }
    }
    
    /**
     * @dev Tính hạng thành viên dựa trên điểm tích lũy
     */
    function _calculateTier(uint256 _lifetimePoints) internal view returns (Tier) {
        if (_lifetimePoints >= tierConfigs[Tier.Platinum].pointsRequired) {
            return Tier.Platinum;
        } else if (_lifetimePoints >= tierConfigs[Tier.Gold].pointsRequired) {
            return Tier.Gold;
        } else if (_lifetimePoints >= tierConfigs[Tier.Silver].pointsRequired) {
            return Tier.Silver;
        }
        return Tier.None;
    }
    
    /**
     * @dev Lấy hệ số thưởng theo hạng
     */
    function _getTierMultiplier(Tier _tier) internal view returns (uint256) {
        if (_tier == Tier.None) {
            return 100; // 1x
        }
        return tierConfigs[_tier].multiplier;
    }
    
    /**
     * @dev Kiểm tra sự kiện đang hoạt động
     */
    function _getActiveEvent(Tier _memberTier) internal view returns (uint256) {
        for (uint256 i = 1; i <= eventCounter; i++) {
            Event storage evt = events[i];
            if (
                evt.isActive &&
                block.timestamp >= evt.startTime &&
                block.timestamp <= evt.endTime &&
                _memberTier >= evt.minTier
            ) {
                return evt.id;
            }
        }
        return 0;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Lấy thông tin thành viên
     */
    function getMember(address _member) external view returns (
        string memory memberId,
        uint256 totalPoints,
        uint256 lifetimePoints,
        uint256 totalSpent,
        Tier tier,
        bool isActive,
        bool isLocked,
        uint256 lastActivityAt
    ) {
        Member storage member = members[_member];
        return (
            member.memberId,
            member.totalPoints,
            member.lifetimePoints,
            member.totalSpent,
            member.tier,
            member.isActive,
            member.isLocked,
            member.lastActivityAt
        );
    }
    
    /**
     * @dev Lấy thông tin thành viên theo Member ID
     */
    function getMemberByMemberId(string memory _memberId) external view returns (
        address walletAddress,
        uint256 totalPoints,
        uint256 lifetimePoints,
        Tier tier,
        bool isActive,
        bool isLocked
    ) {
        address wallet = memberIdToAddress[_memberId];
        require(wallet != address(0), "Member not found");
        
        Member storage member = members[wallet];
        return (
            member.walletAddress,
            member.totalPoints,
            member.lifetimePoints,
            member.tier,
            member.isActive,
            member.isLocked
        );
    }
    
    /**
     * @dev Lấy lịch sử giao dịch của thành viên
     */
    function getMemberTransactions(address _member) external view returns (uint256[] memory) {
        return memberTransactions[_member];
    }
    
    /**
     * @dev Lấy chi tiết giao dịch
     */
    function getTransaction(uint256 _txId) external view returns (
        address member,
        TransactionType txType,
        int256 points,
        uint256 amount,
        string memory invoiceId,
        uint256 timestamp,
        string memory note
    ) {
        Transaction storage tx = transactions[_txId];
        return (
            tx.member,
            tx.txType,
            tx.points,
            tx.amount,
            tx.invoiceId,
            tx.timestamp,
            tx.note
        );
    }
    
    /**
     * @dev Lấy thông tin sự kiện
     */
    function getEvent(uint256 _eventId) external view returns (
        string memory name,
        uint256 startTime,
        uint256 endTime,
        uint256 multiplier,
        Tier minTier,
        bool isActive
    ) {
        Event storage evt = events[_eventId];
        return (
            evt.name,
            evt.startTime,
            evt.endTime,
            evt.multiplier,
            evt.minTier,
            evt.isActive
        );
    }
    
    /**
     * @dev Lấy danh sách sự kiện đang hoạt động
     */
    function getActiveEvents() external view returns (uint256[] memory) {
        uint256[] memory activeEventIds = new uint256[](eventCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= eventCounter; i++) {
            Event storage evt = events[i];
            if (
                evt.isActive &&
                block.timestamp >= evt.startTime &&
                block.timestamp <= evt.endTime
            ) {
                activeEventIds[count] = evt.id;
                count++;
            }
        }
        
        // Tạo mảng với kích thước chính xác
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeEventIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev Lấy thông tin quà tặng
     */
    function getReward(uint256 _rewardId) external view returns (
        string memory name,
        uint256 pointsCost,
        Tier minTier,
        uint256 quantity,
        bool isActive
    ) {
        Reward storage reward = rewards[_rewardId];
        return (
            reward.name,
            reward.pointsCost,
            reward.minTier,
            reward.quantity,
            reward.isActive
        );
    }
    
    /**
     * @dev Lấy danh sách quà tặng khả dụng
     */
    function getAvailableRewards() external view returns (uint256[] memory) {
        uint256[] memory availableRewardIds = new uint256[](rewardCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= rewardCounter; i++) {
            Reward storage reward = rewards[i];
            if (reward.isActive && reward.quantity > 0) {
                availableRewardIds[count] = reward.id;
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = availableRewardIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev Lấy cấu hình hạng
     */
    function getTierConfig(Tier _tier) external view returns (
        uint256 pointsRequired,
        uint256 multiplier,
        uint256 validityPeriod
    ) {
        TierConfig storage config = tierConfigs[_tier];
        return (
            config.pointsRequired,
            config.multiplier,
            config.validityPeriod
        );
    }
    
    /**
     * @dev Lấy thông tin yêu cầu tích điểm thủ công
     */
    function getManualRequest(uint256 _requestId) external view returns (
        address member,
        string memory invoiceId,
        uint256 amount,
        uint256 pointsToEarn,
        address requestedBy,
        RequestStatus status,
        string memory note
    ) {
        ManualRequest storage request = manualRequests[_requestId];
        return (
            request.member,
            request.invoiceId,
            request.amount,
            request.pointsToEarn,
            request.requestedBy,
            request.status,
            request.note
        );
    }
    
    /**
     * @dev Lấy danh sách yêu cầu đang chờ duyệt
     */
    function getPendingRequests() external view returns (uint256[] memory) {
        uint256[] memory pendingRequestIds = new uint256[](requestCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= requestCounter; i++) {
            if (manualRequests[i].status == RequestStatus.Pending) {
                pendingRequestIds[count] = i;
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = pendingRequestIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev Kiểm tra hóa đơn đã được xử lý chưa
     */
    function isInvoiceProcessed(string memory _invoiceId) external view returns (bool) {
        return processedInvoices[_invoiceId];
    }
    
    /**
     * @dev Lấy số lượng yêu cầu hàng ngày của nhân viên
     */
    function getStaffDailyRequests(address _staff) external view returns (uint256) {
        if (block.timestamp / 1 days > lastRequestDate[_staff] / 1 days) {
            return 0;
        }
        return staffDailyRequests[_staff];
    }
    
    /**
     * @dev Lấy tổng số thành viên theo hạng
     */
    function getMemberCountByTier(Tier _tier) external view returns (uint256) {
        uint256 count = 0;
        // Note: Trong production, nên sử dụng mapping riêng để track số lượng
        // thay vì loop qua toàn bộ members
        return count;
    }
    
    /**
     * @dev Lấy thống kê tổng quan hệ thống
     */
    function getSystemStats() external view returns (
        uint256 totalIssued,
        uint256 totalRedeemed,
        uint256 totalMembers,
        uint256 totalTransactions,
        uint256 totalEvents,
        uint256 totalRewards
    ) {
        return (
            totalPointsIssued,
            totalPointsRedeemed,
            0, // Cần implement counter riêng cho members
            transactionCounter,
            eventCounter,
            rewardCounter
        );
    }
    
    /**
     * @dev Tính điểm sẽ nhận được từ số tiền thanh toán
     */
    function calculatePointsFromAmount(
        uint256 _amount,
        address _member
    ) external view returns (uint256) {
        uint256 basePoints = _amount / exchangeRate;
        
        if (!members[_member].isActive) {
            return basePoints;
        }
        
        Member storage member = members[_member];
        uint256 tierMultiplier = _getTierMultiplier(member.tier);
        uint256 points = (basePoints * tierMultiplier) / 100;
        
        uint256 activeEventId = _getActiveEvent(member.tier);
        if (activeEventId > 0) {
            Event storage evt = events[activeEventId];
            points = (points * evt.multiplier) / 100;
            
            if (evt.maxPointsPerInvoice > 0 && points > evt.maxPointsPerInvoice) {
                points = evt.maxPointsPerInvoice;
            }
        }
        
        return points;
    }
    
    /**
     * @dev Kiểm tra xem thành viên có đủ điều kiện đổi quà không
     */
    function canRedeemReward(address _member, uint256 _rewardId) external view returns (bool) {
        if (!members[_member].isActive || members[_member].isLocked) {
            return false;
        }
        
        Member storage member = members[_member];
        Reward storage reward = rewards[_rewardId];
        
        return (
            reward.isActive &&
            reward.quantity > 0 &&
            member.totalPoints >= reward.pointsCost &&
            member.tier >= reward.minTier
        );
    }
}