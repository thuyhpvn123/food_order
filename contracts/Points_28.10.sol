// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// /**
//  * @title RestaurantLoyaltySystem
//  * @dev Hệ thống tích điểm khách hàng thân thiết cho nhà hàng trên MetaNode Blockchain
//  */
// import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "./interfaces/IPoint.sol";
// import "./interfaces/IManagement.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "forge-std/console.sol";

// contract RestaurantLoyaltySystem is
//     Initializable, 
//     ReentrancyGuardUpgradeable, 
//     OwnableUpgradeable, 
//     PausableUpgradeable, 
//     UUPSUpgradeable  
// {
//    using Strings for uint256;
//     // ============ STATE VARIABLES ============
//     IManagement public MANAGEMENT;
//     address public Order;
//     uint256 public exchangeRate;                   // Tỷ giá: X VND = 1 điểm
//     uint256 public pointExpiryPeriod;              // Thời gian hết hạn điểm (giây)
//     uint256 public totalPointsIssued;              // Tổng điểm đã phát hành/ đang lưu hành
//     uint256 public totalPointsRedeemed;            // Tổng điểm đã đổi
//     uint256 public sessionDuration;                // Thời gian lưu phiên (giây)
    
//     // Counters
//     uint256 private transactionCounter;
//     uint256 private eventCounter;
//     uint256 private rewardCounter;
//     uint256 private issuanceCounter;
//     uint256 private requestCounter;
    
//     // Mappings
//     mapping(address => Member) public members;
//     mapping(string => address) public memberIdToAddress;
//     mapping(uint256 => Transaction) public transactions;
//     mapping(uint256 => Event) public events;
//     mapping(uint256 => Reward) public rewards;
//     mapping(bytes32 => TierConfig) public tierConfigs;
//     mapping(uint256 => PointIssuance) public issuances;
//     mapping(uint256 => ManualRequest) public manualRequests;
//     mapping(address => uint256[]) public memberTransactions;
//     mapping(address => uint256) public staffDailyRequests; // Giới hạn yêu cầu/ngày
//     mapping(address => uint256) public lastRequestDate;
//     mapping(bytes32 => bool) public processedInvoices; // Chống trùng hóa đơn
//     bytes32 constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
//     uint256 public totalPointApproved; //tổng điểm đã phát hành
//     bool public isApplyWithOtherDiscount;
//     Transaction[] public allTransactions;
//     bool public isUnlimitedIssue;
//     uint256 public accumulationPercent; //Tỷ lệ tích điểm trên hóa đơn
//     uint256 public maxPercentPerInvoice; //Hạn mức sử dụng cho mỗi bill-> % bill tối đa được dùng để thanh toán
//     string public namePoint;
//     TierConfig[] public allTiers;
//     Member[] public allMembers;
//     uint public validityPeriod;
//     mapping(bytes32 => MemberGroup) public memberGroups;
//     mapping(address => bytes32) public memberToGroup; // member address => group id
//     mapping(bytes32 => address[]) public groupMembers; // group id => member addresses
//     bytes32[] public allGroupIds;
//     MemberGroup[] public allMemberGroups;
//     // mapping(address => mapping(string => bool)) public memberVoucherRedeemed; // member => discount code => đã redeem chưa
//     mapping(address => string[]) public memberVouchers; // Danh sách voucher của member
//     mapping(address => mapping(string => MemberVoucher[])) public memberVoucherDetails;
//     mapping(address => PaymentTransaction[]) public memberPaymentHistory;
//     mapping(string => TierConfig) public mNameToTierConfig;

//     // ============ EVENTS ============
    
//     event MemberRegistered(address indexed wallet, string memberId, uint256 timestamp);
//     event PointsEarned(address indexed member, uint256 points, bytes32 invoiceId, uint256 timestamp);
//     event PointsRedeemed(address indexed member, uint256 points, uint256 rewardId, uint256 timestamp);
//     event TierUpdated(address indexed member, uint oldTierId, uint newTierId, uint256 timestamp);
//     event PointsExpired(address indexed member, uint256 points, uint256 timestamp);
//     event EventCreated(uint256 indexed eventId, string name, uint256 startTime, uint256 endTime);
//     event RewardCreated(uint256 indexed rewardId, string name, uint256 pointsCost);
//     event TransactionCreated(uint256 indexed txId, address indexed member, TransactionType txType, int256 points);
//     event MemberLocked(address indexed member, address indexed admin, string reason, uint256 timestamp);
//     event MemberUnlocked(address indexed member, address indexed admin, uint256 timestamp);
//     event PointsIssued(uint256 amount, address indexed issuedBy, uint256 timestamp);
//     event ManualRequestCreated(uint256 indexed requestId, address indexed member, address indexed staff, uint256 timestamp);
//     event ManualRequestProcessed(uint256 indexed requestId, bool approved, address indexed admin, uint256 timestamp);
//     event PointsRefunded(address indexed member, uint256 points, bytes32 invoiceId, string reason, uint256 timestamp);
//     event RoleGranted(address indexed account, Role role, address indexed admin);
//     event RoleRevoked(address indexed account, address indexed admin);
//     event MemberGroupCreated(bytes32 indexed groupId, string name, uint256 timestamp);
//     event MemberGroupUpdated(bytes32 indexed groupId, string name, uint256 timestamp);
//     event MemberGroupDeleted(bytes32 indexed groupId, uint256 timestamp);
//     event MemberAssignedToGroup(address indexed member, bytes32 indexed groupId, uint256 timestamp);
//     event MemberRemovedFromGroup(address indexed member, bytes32 indexed groupId, uint256 timestamp);
//     event VoucherRedeemed(address indexed member, string voucherCode, uint256 pointsSpent, uint256 timestamp);
//     event VoucherUsed(address indexed member, string voucherCode, uint256 timestamp);
//     event PointsUsedForPayment(address indexed member, bytes32 indexed paymentId, uint256 pointsUsed, uint256 orderAmount, uint256 timestamp);


//     // ============ MODIFIERS ============
        
//     modifier onlyAdmin() {
//         require(MANAGEMENT.hasRole(ROLE_ADMIN, msg.sender) , "Only admin");
//         _;
//     }
    
//     modifier onlyStaffOrAdmin() {
//         require(MANAGEMENT.isStaff(msg.sender), "Only staff or admin");
//         _;
//     }
//     modifier memberExists(address _member) {
//         require(members[_member].isActive, "Member not found");
//         _;
//     }
    
//     modifier notLocked(address _member) {
//         require(!members[_member].isLocked, "Account is locked");
//         _;
//     }
//     uint256[10] private __gap;

//     constructor() {
//         _disableInitializers();
//     }
//     function initialize() public initializer {
//         __ReentrancyGuard_init();
//         __Ownable_init(msg.sender);
//         __Pausable_init();
//         __UUPSUpgradeable_init();
//         exchangeRate = 10000; // 10,000 VND = 1 điểm
//         pointExpiryPeriod = 365 days; // 12 tháng
//         sessionDuration = 30 days; // 30 ngày
//     }    

//     function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
//     // ============ MEMBER FUNCTIONS ============
//     modifier onlyOrder {
//         require(msg.sender == Order,"onlyOrder can call");
//         _;
//     }
//     /**
//      * @dev Đăng ký thành viên mới
//      */
//     function setManagementSC(address _management)external onlyOwner {
//         MANAGEMENT = IManagement(_management);
//     } 
//     function setOrder(address _order)external onlyOwner {
//         Order = _order;
//     } 

//     function registerMember(
//         RegisterInPut memory input
//     ) external {
//         require(bytes(input._memberId).length >= 8 && bytes(input._memberId).length <= 12, "Invalid member ID length");
//         require(!members[msg.sender].isActive, "Already registered");
//         require(memberIdToAddress[input._memberId] == address(0), "Member ID already exists");
        
//         members[msg.sender] = Member({
//             memberId: input._memberId,
//             walletAddress: msg.sender,
//             totalPoints: 0,
//             lifetimePoints: 0,
//             totalSpent: 0,
//             tierID: bytes32(0), 
//             // tierUpdatedAt: block.timestamp,
//             lastBuyActivityAt: 0,
//             isActive: true,
//             isLocked: false,
//             phoneNumber: input._phoneNumber,
//             firstName: input._firstName,
//             lastName: input._lastName,
//             whatsapp: input._whatsapp,
//             email: input._email,
//             avatar: input._avatar
//         });
        
//         memberIdToAddress[input._memberId] = msg.sender;
//         allMembers.push(members[msg.sender]);
//         emit MemberRegistered(msg.sender,input. _memberId, block.timestamp);
//     }
//     //contract Order gọi
//     function updateLastBuyActivityAt(address user) external onlyOrder{
//         members[msg.sender].lastBuyActivityAt = block.timestamp;
//     }
//     function isMemberPointSystem(address _user) external view returns (bool){
//         return(members[_user].isActive);
//     }
//     function GetAllMembersPagination(
//         uint256 offset, 
//         uint256 limit
//     )
//         external
//         view
//         returns (Member[] memory result,uint totalCount)
//     {
//         uint length = allMembers.length;
//         if(offset >= length) {
//             return ( new Member[](0),length);
//         }

//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         result = new Member[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = length - 1 - offset - i;
//             result[i] = allMembers[reverseIndex];
//         }

//         return (result,length);
//     }
//     function DeleteMember(address _member) external onlyAdmin {
//         require(members[_member].walletAddress != address(0), "Member not found");
        
//         Member storage member = members[_member];
//         string memory memberId = member.memberId;
        
//         // Xóa mapping
//         delete memberIdToAddress[memberId];
//         delete members[_member];
        
//         // Xóa khỏi allMembers array
//         for (uint256 i = 0; i < allMembers.length; i++) {
//             if (allMembers[i].walletAddress == _member) {
//                 // Di chuyển phần tử cuối lên vị trí hiện tại
//                 allMembers[i] = allMembers[allMembers.length - 1];
//                 allMembers.pop();
//                 break;
//         }
//         }
//     }
//     function _isValidAmount(bytes32 _paymentId,uint _amount)internal view returns(bool){
//         require(Order != address(0),"Order address not set yet");
//         return IOrder(Order).isValidAmount(_paymentId,_amount);
//     } 
//     /**
//      * @dev Tích điểm tự động (khi thanh toán)
//      */
//     function earnPoints(
//         string memory _memberID,
//         uint256 _amount,
//         bytes32  _invoiceId,
//         uint256 _eventId
//     ) external {
//         address _member = memberIdToAddress[_memberID];
//         require(members[_member].isActive, "Member not found");
//         require(!members[_member].isLocked, "Account is locked");
//         require(!processedInvoices[_invoiceId], "Invoice already processed");
//         require(_amount > 0, "Invalid amount");
//         require(_isValidAmount(_invoiceId,_amount),"amount earnPoint not match invoiceId");
//         Member storage member = members[_member];
//         // tính điểm sau khi áp dụng tỷ lệ tích điểm trên hóa đơn
//         uint256  amountAfter = _amount * accumulationPercent/100;
//         // Tính điểm dựa trên số tiền và tỷ giá
//         uint256 basePoints = amountAfter / exchangeRate;
//         // Áp dụng hệ số hạng thành viên
//         uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//         uint256 points = (basePoints * tierMultiplier) / 100;

//         // Kiểm tra sự kiện đang diễn ra
//         if (_eventId > 0){
//             require(_isEventValidForMember(_eventId, member.tierID), "Event not valid for this member");
//             Event storage evt = events[_eventId];
//             points = points + evt.pointPlus;
                        
//         }
//         // Cập nhật điểm thành viên
//         member.totalPoints += points;
        
//         member.lifetimePoints += points;
//         member.totalSpent += _amount;
        
//         // Cập nhật hạng nếu đạt điều kiện
//         _updateMemberTier(_member);
        
//         // Ghi nhận giao dịch
//         _createTransaction(
//             _member,
//             TransactionType.Earn,
//             int256(points),
//             _amount,
//             _invoiceId,
//             "",
//             _eventId
//         );
        
//         // Đánh dấu hóa đơn đã xử lý
//         processedInvoices[_invoiceId] = true;
        
//         totalPointsIssued += points;
        
//         emit PointsEarned(_member, points, _invoiceId, block.timestamp);
//     }
//     /**
//  * @dev Kiểm tra event có hợp lệ với member tier hay không
//  */
// function _isEventValidForMember(uint256 _eventId, bytes32 _memberTierID) internal view returns (bool) {
//     if (_eventId == 0 || _eventId > eventCounter) {
//         return false;
//     }
    
//     Event storage evt = events[_eventId];
//     uint256 memberTierLevel = _getTierLevel(_memberTierID);
//     uint256 eventMinTierLevel = _getTierLevel(evt.minTierID);
    
//     // Kiểm tra event có active và member có đủ tier level không
//     return (
//         evt.isActive &&
//         block.timestamp >= evt.startTime &&
//         block.timestamp <= evt.endTime &&
//         memberTierLevel >= eventMinTierLevel
//     );
// }
// //     /**
// //      * @dev Đổi điểm lấy quà
// //      */
// // function redeemPoints(uint256 _rewardId) external memberExists(msg.sender) notLocked(msg.sender) {
// //     Member storage member = members[msg.sender];
// //     Reward storage reward = rewards[_rewardId];
    
// //     require(reward.isActive, "Reward not active");
// //     require(reward.quantity > 0, "Reward out of stock");
// //     require(member.totalPoints >= reward.pointsCost, "Insufficient points");
    
// //     // So sánh tier level thay vì dùng enum
// //     uint256 memberTierLevel = _getTierLevel(member.tierID);
// //     uint256 rewardMinTierLevel = _getTierLevel(reward.minTierID);
// //     require(memberTierLevel >= rewardMinTierLevel, "Tier requirement not met");
    
// //     // Trừ điểm
// //     member.totalPoints -= reward.pointsCost;
// //     // member.lastBuyActivityAt = block.timestamp;
// //     reward.quantity -= 1;
    
// //     // Ghi nhận giao dịch
// //     _createTransaction(
// //         msg.sender,
// //         TransactionType.Redeem,
// //         -int256(reward.pointsCost),
// //         0,
// //         bytes32(0),
// //         reward.name,
// //         0
// //     );
    
// //     totalPointsRedeemed += reward.pointsCost;
    
// //     emit PointsRedeemed(msg.sender, reward.pointsCost, _rewardId, block.timestamp);
// // }    
//     // ============ STAFF FUNCTIONS ============
    
//     /**
//      * @dev Nhân viên tạo yêu cầu tích điểm thủ công
//      */
//     function createManualRequest(
//         string memory _memberID,
//         bytes32 _invoiceId,
//         uint256 _amount,
//         RequestEarnPointType _typeRequest,
//         string memory _img
//     ) external onlyStaffOrAdmin returns (uint256) {
//         address _member = memberIdToAddress[_memberID];
//         require(members[_member].isActive, "Member not found");
//         require(!processedInvoices[_invoiceId], "Invoice already processed");
        
//         // Kiểm tra giới hạn yêu cầu hàng ngày
//         if (block.timestamp / 1 days > lastRequestDate[msg.sender] / 1 days) {
//             staffDailyRequests[msg.sender] = 0;
//             lastRequestDate[msg.sender] = block.timestamp;
//         }
        
//         require(staffDailyRequests[msg.sender] < 50, "Daily request limit reached");
        
//         uint256 pointsToEarn = _amount / exchangeRate;
        
//         requestCounter++;
//         manualRequests[requestCounter] = ManualRequest({
//             id: requestCounter,
//             member: _member,
//             invoiceId: _invoiceId,
//             amount: _amount,
//             pointsToEarn: pointsToEarn,
//             requestedBy: msg.sender,
//             requestTime: block.timestamp,
//             status: RequestStatus.Pending,
//             approvedBy: address(0),
//             approvedTime: 0,
//             rejectReason: "",
//             typeRequest: _typeRequest,
//             img: _img
//         });
        
//         staffDailyRequests[msg.sender]++;
        
//         emit ManualRequestCreated(requestCounter, _member, msg.sender, block.timestamp);
        
//         return requestCounter;
//     }
    
//     /**
//      * @dev Nhân viên quét QR và trừ điểm cho khách
//      */
//     function redeemPointsForCustomer(
//         address _member,
//         uint256 _points,
//         string memory _note
//     ) external onlyStaffOrAdmin memberExists(_member) notLocked(_member) {
//         Member storage member = members[_member];
        
//         require(member.totalPoints >= _points, "Insufficient points");
        
//         member.totalPoints -= _points;
//         // member.lastBuyActivityAt = block.timestamp;
        
//         _createTransaction(
//             _member,
//             TransactionType.Redeem,
//             -int256(_points),
//             0,
//             "",
//             _note,
//             0
//         );
        
//         totalPointsRedeemed += _points;
//     }
    
//     // ============ ADMIN FUNCTIONS ============
    
//     /**
//      * @dev Phát hành Xu (tạo điểm mới cho hệ thống)
//      */
//     function issuePoints(
//         uint256 _amount, 
//         string memory _namePoint, 
//         bool _isUnlimitedIssue,
//         uint256 _accumulationPercent,
//         uint256 _maxPercentPerInvoice,
//         uint256 _newRate,
//         bool _isApplyWithOtherDiscount
//     ) external onlyAdmin {
//         require(_newRate > 0, "Invalid rate");
//         require(_amount > 0 || _isUnlimitedIssue == true , "Invalid amount");
        
//         namePoint = _namePoint;
//         accumulationPercent =  _accumulationPercent;
//         maxPercentPerInvoice = _maxPercentPerInvoice;
//         isUnlimitedIssue = _isUnlimitedIssue;
//         totalPointApproved += _amount;
//         _createTransaction(
//             msg.sender,
//             TransactionType.Issue,
//             int256(_amount),
//             _amount,
//             bytes32(0),
//             "issuePoints",
//             0
//         );
//         exchangeRate = _newRate;
//         isApplyWithOtherDiscount = _isApplyWithOtherDiscount;
//         emit PointsIssued( _amount, msg.sender, block.timestamp);

//     }
//     /**
//     * @dev Lấy config cho payment
//     */
//     function getPaymentConfig() external view returns (
//         uint256 exchangeRate,
//         uint256 maxPercentPerInvoice
//     ) {
//         return (exchangeRate, maxPercentPerInvoice);
//     }

//     function updateIssuePoints(
//         string memory _namePoint, 
//         bool _isUnlimitedIssue,
//         uint256 _accumulationPercent, //%ty le tich diem
//         uint256 _maxPercentPerInvoice, //%Han muc su dung diem de thanh toan cua moi hoa don
//         uint256 _newRate,
//         bool _isApplyWithOtherDiscount
//     ) external onlyAdmin {
//         require(_newRate > 0, "Invalid rate");
//         namePoint = _namePoint;
//         accumulationPercent = _accumulationPercent;
//         maxPercentPerInvoice = _maxPercentPerInvoice;
//         isUnlimitedIssue = _isUnlimitedIssue;
//         exchangeRate = _newRate;
//         isApplyWithOtherDiscount = _isApplyWithOtherDiscount;

//     }
//     function issueMorePoint(uint _amount, string memory _note)external onlyAdmin{
//         totalPointApproved += _amount;
//         _createTransaction(
//             msg.sender,
//             TransactionType.Issue,
//             int256(_amount),
//             _amount,
//             bytes32(0),
//             _note,
//             0
//         );
//         emit PointsIssued( _amount, msg.sender, block.timestamp);

//     }
//     /**
//      * @dev Duyệt yêu cầu tích điểm thủ công
//      */
//     function approveManualRequest(uint256 _requestId) external onlyAdmin {
//         ManualRequest storage request = manualRequests[_requestId];
        
//         // require(request.status == RequestStatus.Pending, "Request already processed");
//         // require(!processedInvoices[request.invoiceId], "Invoice already processed");
//         require(request.status != RequestStatus.Approved, "Request already approved");
        
//         Member storage member = members[request.member];
        
//         // Tính điểm với hệ số hạng
//         uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//         uint256 points = (request.pointsToEarn * tierMultiplier) / 100;
        
//         // Cộng điểm
//         member.totalPoints += points;
//         member.lifetimePoints += points;
//         member.totalSpent += request.amount;
//         // member.lastBuyActivityAt = block.timestamp;
        
//         // Cập nhật yêu cầu
//         request.status = RequestStatus.Approved;
//         request.approvedBy = msg.sender;
//         request.approvedTime = block.timestamp;
        
//         // Đánh dấu hóa đơn
//         processedInvoices[request.invoiceId] = true;
        
//         // Cập nhật hạng
//         _updateMemberTier(request.member);
        
//         // // Tạo giao dịch
//         // _createTransaction(
//         //     request.member,
//         //     TransactionType.Earn,
//         //     int256(points),
//         //     request.amount,
//         //     request.invoiceId,
//         //     request.note,
//         //     0
//         // );
        
//         totalPointsIssued += points;
        
//         emit ManualRequestProcessed(_requestId, true, msg.sender, block.timestamp);
//     }
    
//     /**
//      * @dev Từ chối yêu cầu tích điểm thủ công
//      */
//     function rejectManualRequest(uint256 _requestId, string memory _reason) external onlyAdmin {
//         ManualRequest storage request = manualRequests[_requestId];
        
//         // require(request.status == RequestStatus.Pending, "Request already processed");
//         require(request.status != RequestStatus.Rejected, "Request already rejected");
    
//         request.status = RequestStatus.Rejected;
//         request.approvedBy = msg.sender;
//         request.approvedTime = block.timestamp;
//         request.rejectReason = _reason;
        
//         emit ManualRequestProcessed(_requestId, false, msg.sender, block.timestamp);
//     }
    
//     /**
//      * @dev Điều chỉnh điểm thủ công
//      */
//     function adjustPoints(
//         address _member,
//         int256 _points,
//         string memory _reason
//     ) external onlyAdmin memberExists(_member) {
//         require(bytes(_reason).length > 0, "Reason required");
        
//         Member storage member = members[_member];
        
//         if (_points > 0) {
//             member.totalPoints += uint256(_points);
//             member.lifetimePoints += uint256(_points);
//         } else {
//             uint256 absPoints = uint256(-_points);
//             require(member.totalPoints >= absPoints, "Insufficient points");
//             member.totalPoints -= absPoints;
//         }
        
//         // member.lastBuyActivityAt = block.timestamp;
        
//         _createTransaction(
//             _member,
//             TransactionType.ManualAdjust,
//             _points,
//             0,
//             "",
//             _reason,
//             0
//         );
        
//         _updateMemberTier(_member);
//     }
    
//     /**
//      * @dev Hoàn điểm khi khách hủy/trả món
//      */
//     function refundPoints(
//         address _member,
//         bytes32 _invoiceId,
//         string memory _reason
//     ) external onlyAdmin memberExists(_member) {
//         require(processedInvoices[_invoiceId], "Invoice not found");
        
//         // Tìm giao dịch tích điểm gốc
//         uint256[] memory txIds = memberTransactions[_member];
//         uint256 pointsToRefund = 0;
        
//         for (uint256 i = 0; i < txIds.length; i++) {
//             Transaction storage _tx = transactions[txIds[i]];
//             if (
//                 _tx.invoiceId == _invoiceId &&
//                 _tx.txType == TransactionType.Earn
//             ) {
//                 pointsToRefund = uint256(_tx.points);
//                 break;
//             }
//         }
        
//         require(pointsToRefund > 0, "Transaction not found");
        
//         Member storage member = members[_member];
//         require(member.totalPoints >= pointsToRefund, "Insufficient points");
        
//         // Trừ điểm
//         member.totalPoints -= pointsToRefund;
//         if (member.lifetimePoints >= pointsToRefund) {
//             member.lifetimePoints -= pointsToRefund;
//         }
        
//         // Tạo giao dịch hoàn điểm
//         _createTransaction(
//             _member,
//             TransactionType.Refund,
//             -int256(pointsToRefund),
//             0,
//             _invoiceId,
//             _reason,
//             0
//         );
        
//         // Xóa đánh dấu hóa đơn
//         processedInvoices[_invoiceId] = false;
        
//         emit PointsRefunded(_member, pointsToRefund, _invoiceId, _reason, block.timestamp);
//     }
    
//     /**
//      * @dev Khóa tài khoản thành viên
//      */
//     function lockMember(address _member, string memory _reason) external onlyAdmin memberExists(_member) {
//         require(!members[_member].isLocked, "Member already locked");
//         require(bytes(_reason).length > 0, "Reason required");
//         members[_member].isLocked = true;
//         emit MemberLocked(_member, msg.sender, _reason, block.timestamp);
//     }
    
//     /**
//      * @dev Mở khóa tài khoản thành viên
//      */
//     function unlockMember(address _member) external onlyAdmin memberExists(_member) {
//         require(members[_member].isLocked, "Member not locked");
//         members[_member].isLocked = false;

//         emit MemberUnlocked(_member, msg.sender, block.timestamp);
//     }

// /**
//  * @dev Tạo nhóm khách hàng mới
//  */
// function createMemberGroup(
//     string memory _name
// ) external onlyAdmin returns (bytes32) {
//     require(bytes(_name).length > 0, "Group name required");
    
//     bytes32 groupId = keccak256(abi.encodePacked(_name, block.timestamp));
//     require(memberGroups[groupId].id == bytes32(0), "Group already exists");
    
//     memberGroups[groupId] = MemberGroup({
//         id: groupId,
//         name: _name,
//         isActive: true
//     });
    
//     allGroupIds.push(groupId);
//     allMemberGroups.push( memberGroups[groupId]);
//     emit MemberGroupCreated(groupId, _name, block.timestamp);
    
//     return groupId;
// }
// function getAllGroups() external view returns (MemberGroup[] memory) {
//     return allMemberGroups;
// }
// function isMemberGroupId(bytes32 groupId) external view returns (bool) {
//     return (memberGroups[groupId].id != bytes32(0));
// }
// /**
//  * @dev Cập nhật thông tin nhóm khách hàng
//  */
// function updateMemberGroup(
//     bytes32 _groupId,
//     string memory _name,
//     bool _isActive
// ) external onlyAdmin {
//     require(memberGroups[_groupId].id != bytes32(0), "Group not found");
//     require(bytes(_name).length > 0, "Group name required");
    
//     MemberGroup storage group = memberGroups[_groupId];
//     group.name = _name;
//     group.isActive = _isActive;
    
//     emit MemberGroupUpdated(_groupId, _name, block.timestamp);
// }

// /**
//  * @dev Xóa nhóm khách hàng
//  */
// function deleteMemberGroup(bytes32 _groupId) external onlyAdmin {
//     require(memberGroups[_groupId].id != bytes32(0), "Group not found");
    
//     // Gỡ tất cả members khỏi group
//     address[] memory membersInGroup = groupMembers[_groupId];
//     for (uint256 i = 0; i < membersInGroup.length; i++) {
//         delete memberToGroup[membersInGroup[i]];
//     }
    
//     // Xóa group
//     delete groupMembers[_groupId];
//     delete memberGroups[_groupId];
    
//     // Xóa khỏi allGroupIds
//     for (uint256 i = 0; i < allGroupIds.length; i++) {
//         if (allGroupIds[i] == _groupId) {
//             allGroupIds[i] = allGroupIds[allGroupIds.length - 1];
//             allGroupIds.pop();
//             break;
//         }
//     }
    
//     emit MemberGroupDeleted(_groupId, block.timestamp);
// }

// /**
//  * @dev Gán member vào nhóm
//  */
// function assignMemberToGroup(
//     address _member,
//     bytes32 _groupId
// ) external onlyAdmin memberExists(_member) {
//     require(memberGroups[_groupId].id != bytes32(0), "Group not found");
//     require(memberGroups[_groupId].isActive, "Group not active");
    
//     // bytes32 oldGroupId = memberToGroup[_member];
    
//     // // Nếu member đã ở group khác, gỡ ra khỏi group cũ
//     // if (oldGroupId != bytes32(0)) {
//     //     _removeMemberFromGroup(_member, oldGroupId);
//     // }
    
//     // Thêm vào group mới
//     memberToGroup[_member] = _groupId;
//     groupMembers[_groupId].push(_member);
    
//     emit MemberAssignedToGroup(_member, _groupId, block.timestamp);
// }
// function getMemberToGroup(address _member) external view returns(bytes32){
//     return memberToGroup[_member];
// }
// /**
//  * @dev Gỡ member khỏi nhóm
//  */
// function removeMemberFromGroup(address _member) external onlyAdmin {
//     bytes32 groupId = memberToGroup[_member];
//     require(groupId != bytes32(0), "Member not in any group");
    
//     _removeMemberFromGroup(_member, groupId);
    
//     emit MemberRemovedFromGroup(_member, groupId, block.timestamp);
// }

// /**
//  * @dev Internal function để gỡ member khỏi group
//  */
// function _removeMemberFromGroup(address _member, bytes32 _groupId) internal {
//     address[] storage members = groupMembers[_groupId];
    
//     for (uint256 i = 0; i < members.length; i++) {
//         if (members[i] == _member) {
//             members[i] = members[members.length - 1];
//             members.pop();
//             break;
//         }
//     }
    
//     delete memberToGroup[_member];
// }

   
 
//     /**
//      * @dev Tạo sự kiện/chương trình khuyến mãi
//      */
//     function createEvent(
//         string memory _name,
//         uint256 _startTime,
//         uint256 _endTime,
//         uint256 _pointPlus,
//         bytes32 _minTierID
//     ) external onlyAdmin returns (uint256) {
//         require(_startTime < _endTime, "Invalid time range");
        
//         eventCounter++;
//         events[eventCounter] = Event({
//             id: eventCounter,
//             name: _name,
//             startTime: _startTime,
//             endTime: _endTime,
//             pointPlus: _pointPlus,
//             minTierID: _minTierID,
//             isActive: true
//             // maxPointsPerInvoice: _maxPointsPerInvoice,
//             // maxPointsPerMember: _maxPointsPerMember,
//             // description: _description
//         });
        
//         emit EventCreated(eventCounter, _name, _startTime, _endTime);
        
//         return eventCounter;
//     }
//     function updateEvent(
//         uint256 _eventId,
//         string memory _name,
//         uint256 _startTime,
//         uint256 _endTime,
//         uint256 _pointPlus,
//         bytes32 _minTierID,
//         bool isActive
//     ) external onlyAdmin returns (uint256) {
//         require(_startTime < _endTime, "Invalid time range");
//         Event storage eventKQ = events[_eventId];
//         eventKQ.name = _name;
//         eventKQ.startTime = _startTime;
//         eventKQ.endTime = _endTime;
//         eventKQ.pointPlus = _pointPlus;
//         eventKQ.minTierID = _minTierID;
//         eventKQ.isActive = true;
        
//     }
// /**
//  * @dev Lấy danh sách sự kiện đang hoạt động với pagination
//  */
// function getActiveEventsPagination(
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     Event[] memory result,
//     uint256 totalCount
// ) {
//     // Đếm số events active
//     uint256 count = 0;
//     for (uint256 i = 1; i <= eventCounter; i++) {
//         Event storage evt = events[i];
//         if (
//             evt.isActive &&
//             block.timestamp >= evt.startTime &&
//             block.timestamp <= evt.endTime
//         ) {
//             count++;
//         }
//     }
    
//     if (count == 0 || offset >= count) {
//         return (new Event[](0), count);
//     }
    
//     // Tạo mảng tạm chứa tất cả active events
//     Event[] memory activeEvents = new Event[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 1; i <= eventCounter; i++) {
//         Event storage evt = events[i];
//         if (
//             evt.isActive &&
//             block.timestamp >= evt.startTime &&
//             block.timestamp <= evt.endTime
//         ) {
//             activeEvents[index] = evt;
//             index++;
//         }
//     }
    
//     // Pagination
//     uint256 end = offset + limit;
//     if (end > count) {
//         end = count;
//     }
    
//     uint256 size = end - offset;
//     result = new Event[](size);
    
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = count - 1 - offset - i;
//         result[i] = activeEvents[reverseIndex];
//     }
    
//     return (result, count);
// }

//     // /**
//     //  * @dev Tạo quà tặng
//     //  */
//     // function createReward(
//     //     string memory _name,
//     //     uint256 _pointsCost,
//     //     bytes32 _minTierID,   
//     //     uint256 _quantity,
//     //     string memory _description
//     // ) external onlyAdmin returns (uint256) {
//     //     require(_pointsCost > 0, "Invalid points cost");
        
//     //     rewardCounter++;
//     //     rewards[rewardCounter] = Reward({
//     //         id: rewardCounter,
//     //         name: _name,
//     //         pointsCost: _pointsCost,
//     //         minTierID: _minTierID,
//     //         quantity: _quantity,
//     //         isActive: true,
//     //         description: _description
//     //     });
        
//     //     emit RewardCreated(rewardCounter, _name, _pointsCost);
        
//     //     return rewardCounter;
//     // }
//     /**
//      * @dev Cập nhật cấu hình hạng thành viên
//      */
//     function createTierConfig(
//         string memory _nameTier,
//         uint256 _pointsRequired,
//         uint256 _multiplier,
//         uint256 _pointsMax,
//         string memory _colour
//     ) external onlyAdmin {
//         // Nếu _pointsMax = 0, nghĩa là không giới hạn trên (vô hạn)
//         if (_pointsMax == 0) {
//             _pointsMax = type(uint256).max;
//         }
//         require(_pointsRequired < _pointsMax, "pointsRequired must be less than pointsMax");
        
//         bytes32 tierID = keccak256(abi.encodePacked(_nameTier,block.timestamp));
//         require(mNameToTierConfig[_nameTier].id == bytes32(0), "_nameTier duplicate");
        
//         // Kiểm tra không trùng khoảng điểm với các tier đã tồn tại
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             TierConfig memory existingTier = allTiers[i];
            
//             // Kiểm tra xem khoảng mới có giao với khoảng cũ không
//             // Khoảng mới: [_pointsRequired, _pointsMax)
//             // Khoảng cũ: [existingTier.pointsRequired, existingTier.pointsMax)
//             bool isOverlapping = !(
//                 _pointsMax <= existingTier.pointsRequired || 
//                 _pointsRequired >= existingTier.pointsMax
//             );
            
//             require(!isOverlapping, "Point range overlaps with existing tier");
//         }
        
//         // Tạo tier mới
//         TierConfig memory newTier = TierConfig({
//             id: tierID,
//             nameTier: _nameTier,
//             pointsRequired: _pointsRequired,
//             pointsMax: _pointsMax,
//             multiplier: _multiplier,
//             colour:_colour
//         });
        
//         tierConfigs[tierID] = newTier;
        
//         // Thêm vào allTiers và sắp xếp theo pointsRequired
//         allTiers.push(newTier);
//         mNameToTierConfig[_nameTier] = newTier;
//         // Sắp xếp allTiers theo pointsRequired (bubble sort - đơn giản cho Solidity)
//         for (uint256 i = 0; i < allTiers.length - 1; i++) {
//             for (uint256 j = 0; j < allTiers.length - i - 1; j++) {
//                 if (allTiers[j].pointsRequired > allTiers[j + 1].pointsRequired) {
//                     TierConfig memory temp = allTiers[j];
//                     allTiers[j] = allTiers[j + 1];
//                     allTiers[j + 1] = temp;
//                 }
//             }
//         }
//     }   
//     // Hàm updateTierConfig:
//     function updateTierConfig(
//         bytes32 _tierID,
//         string memory _nameTier,
//         uint256 _pointsRequired,
//         uint256 _multiplier,
//         uint256 _pointsMax,
//         string memory _colour
//     ) external onlyAdmin {
//         require(tierConfigs[_tierID].id != bytes32(0), "Tier not found");
//         // Nếu _pointsMax = 0, nghĩa là không giới hạn trên (vô hạn)
//         if (_pointsMax == 0) {
//             _pointsMax = type(uint256).max;
//         }
        
//         require(_pointsRequired < _pointsMax, "pointsRequired must be less than pointsMax");
        
//         // Kiểm tra không trùng khoảng điểm (trừ chính tier đang update)
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             TierConfig memory existingTier = allTiers[i];
            
//             if (existingTier.id == _tierID) continue; // Bỏ qua tier đang update
            
//             bool isOverlapping = !(
//                 _pointsMax <= existingTier.pointsRequired || 
//                 _pointsRequired >= existingTier.pointsMax
//             );
            
//             require(!isOverlapping, "Point range overlaps with existing tier");
//         }
//         if(bytes(_nameTier).length >0){
//             require(mNameToTierConfig[_nameTier].id == bytes32(0), "_nameTier duplicate");
//             tierConfigs[_tierID].nameTier = _nameTier;
//         }
//         if(bytes(_colour).length >0){
//             tierConfigs[_tierID].colour = _colour;
//         }
//         // Cập nhật tier
//         if(_pointsRequired >0) tierConfigs[_tierID].pointsRequired = _pointsRequired;
        
//         if(_pointsMax >0) tierConfigs[_tierID].pointsMax = _pointsMax;
//         if(_multiplier >0) tierConfigs[_tierID].multiplier = _multiplier;
        
//         mNameToTierConfig[_nameTier] = tierConfigs[_tierID];
//         // Cập nhật trong allTiers
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             if (allTiers[i].id == _tierID) {
//                 allTiers[i] = tierConfigs[_tierID];
//                 break;
//             }
//         }
//         if(allTiers.length >1){
//             // Sắp xếp lại allTiers
//             for (uint256 i = 0; i < allTiers.length - 1; i++) {
//                 for (uint256 j = 0; j < allTiers.length - i - 1; j++) {
//                     if (allTiers[j].pointsRequired > allTiers[j + 1].pointsRequired) {
//                         TierConfig memory temp = allTiers[j];
//                         allTiers[j] = allTiers[j + 1];
//                         allTiers[j + 1] = temp;
//                     }
//                 }
//             }

//         }
//     }
//     function setValidityPeriod(uint _validityPeriod) external onlyAdmin {
//         validityPeriod = _validityPeriod;
//     }
//     /**
//      * @dev Lấy cấu hình hạng
//      */
//     function getTierConfig(bytes32 _tierID) external view returns (
//         string memory nameTier,
//         uint256 pointsRequired,
//         uint256 multiplier,
//         // uint256 validityPeriod
//         uint256 pointsMax
//     ) {
//         TierConfig storage config = tierConfigs[_tierID];
//         return (
//             config.nameTier,
//             config.pointsRequired,
//             config.multiplier,
//             config.pointsMax
//             // config.validityPeriod
//         );
//     }
//     function getTierConfigFromName(string memory _nameTier) external view returns(TierConfig memory){
//         return mNameToTierConfig[_nameTier];
//     }

//     // Hàm deleteTierConfig:
//     function deleteTierConfig(bytes32 _tierID) external onlyAdmin {
//         require(tierConfigs[_tierID].id != bytes32(0), "Tier not found");
        
//         // Xóa khỏi mapping
//         delete tierConfigs[_tierID];
        
//         // Xóa khỏi allTiers
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             if (allTiers[i].id == _tierID) {
//                 // Di chuyển phần tử cuối lên vị trí hiện tại
//                 allTiers[i] = allTiers[allTiers.length - 1];
//                 allTiers.pop();
//                 break;
//             }
//         }
//         if(allTiers.length >1){
//             // Sắp xếp lại (vì đã thay đổi thứ tự)
//             for (uint256 i = 0; i < allTiers.length - 1; i++) {
//                 for (uint256 j = 0; j < allTiers.length - i - 1; j++) {
//                     if (allTiers[j].pointsRequired > allTiers[j + 1].pointsRequired) {
//                         TierConfig memory temp = allTiers[j];
//                         allTiers[j] = allTiers[j + 1];
//                         allTiers[j + 1] = temp;
//                     }
//                 }
//             }

//         }
//         delete mNameToTierConfig[tierConfigs[_tierID].nameTier];
//     }

//     // Hàm getAllTiers:
//     function getAllTiers() external view returns (TierConfig[] memory) {
//         return allTiers;
//     }
//     /**
//      * @dev Cập nhật tỷ giá quy đổi
//      */
//     function updateExchangeRate(uint256 _newRate) external onlyAdmin {
//         require(_newRate > 0, "Invalid rate");
//         exchangeRate = _newRate;
//     }
    
//     /**
//      * @dev Cập nhật thời gian hết hạn điểm
//      */
//     function updatePointExpiryPeriod(uint256 _newPeriod) external onlyAdmin {
//         pointExpiryPeriod = _newPeriod;
//     }
    
//     /**
//      * @dev Cập nhật thời gian lưu phiên
//      */
//     function updateSessionDuration(uint256 _newDuration) external onlyAdmin {
//         sessionDuration = _newDuration;
//     }
    
//     /**
//      * @dev Bật/tắt sự kiện
//      */
//     function toggleEvent(uint256 _eventId, bool _isActive) external onlyAdmin {
//         require(events[_eventId].id > 0, "Event not found");
//         events[_eventId].isActive = _isActive;
//     }
    
//     // /**
//     //  * @dev Bật/tắt quà tặng
//     //  */
//     // function toggleReward(uint256 _rewardId, bool _isActive) external onlyAdmin {
//     //     require(rewards[_rewardId].id > 0, "Reward not found");
//     //     rewards[_rewardId].isActive = _isActive;
//     // }
    
//     // /**
//     //  * @dev Cập nhật số lượng quà tặng
//     //  */
//     // function updateRewardQuantity(uint256 _rewardId, uint256 _newQuantity) external onlyAdmin {
//     //     require(rewards[_rewardId].id > 0, "Reward not found");
//     //     rewards[_rewardId].quantity = _newQuantity;
//     // }
    
//     /**
//      * @dev Xử lý điểm hết hạn (gọi định kỳ bởi backend)
//      */
//    function expirePoints(address _member) external onlyAdmin memberExists(_member) {
//     Member storage member = members[_member];
    
//     // Kiểm tra thời gian không hoạt động
//     if (block.timestamp - member.lastBuyActivityAt > pointExpiryPeriod) {
//         uint256 expiredPoints = member.totalPoints;
        
//         if (expiredPoints > 0) {
//             member.totalPoints = 0;
            
//             _createTransaction(
//                 _member,
//                 TransactionType.Expire,
//                 -int256(expiredPoints),
//                 0,
//                 bytes32(0),
//                 "Points expired due to inactivity",
//                 0
//             );
            
//             emit PointsExpired(_member, expiredPoints, block.timestamp);
//         }
        
//         // Hạ hạng về None
//         if (member.tierID != bytes32(0)) {
//             bytes32 oldTierID = member.tierID;
//             member.tierID = bytes32(0);
//             // member.tierUpdatedAt = block.timestamp;
            
//             emit TierUpdated(
//                 _member, 
//                 uint256(uint160(address(uint160(uint256(oldTierID))))), 
//                 uint256(uint160(address(uint160(uint256(bytes32(0)))))), 
//                 block.timestamp
//             );
//         }
//     }
// }
//     /**
//  * @dev Lấy danh sách members có điểm sắp hết hạn
//  */
// function getMembersNearExpiry(uint256 _daysBeforeExpiry) external view returns (address[] memory) {
//     uint256 expiryThreshold = block.timestamp - pointExpiryPeriod + (_daysBeforeExpiry * 1 days);
//     address[] memory nearExpiryMembers = new address[](allMembers.length);
//     uint256 count = 0;
    
//     for (uint256 i = 0; i < allMembers.length; i++) {
//         Member memory member = allMembers[i];
        
//         if (
//             member.isActive && 
//             !member.isLocked &&
//             member.totalPoints > 0 &&
//             member.lastBuyActivityAt <= expiryThreshold
//         ) {
//             nearExpiryMembers[count] = member.walletAddress;
//             count++;
//         }
//     }
    
//     // Tạo mảng với kích thước chính xác
//     address[] memory result = new address[](count);
//     for (uint256 i = 0; i < count; i++) {
//         result[i] = nearExpiryMembers[i];
//     }
    
//     return result;
// }

// // Thêm hàm kiểm tra member có điểm sắp hết hạn không:
// /**
//  * @dev Kiểm tra member có điểm sắp hết hạn không
//  */
// function isPointsNearExpiry(address _member) external view returns (
//     bool isExpiring,
//     uint256 daysUntilExpiry,
//     uint256 pointsToExpire
// ) {
//     if (!members[_member].isActive) {
//         return (false, 0, 0);
//     }
    
//     Member storage member = members[_member];
//     uint256 inactiveDuration = block.timestamp - member.lastBuyActivityAt;
    
//     if (inactiveDuration >= pointExpiryPeriod) {
//         return (true, 0, member.totalPoints);
//     }
    
//     uint256 timeUntilExpiry = pointExpiryPeriod - inactiveDuration;
//     uint256 daysData = timeUntilExpiry / 1 days;
    
//     // Coi là "sắp hết hạn" nếu còn <= 30 ngày
//     bool expiring = daysData <= 30;
    
//     return (expiring, daysData, member.totalPoints);
// }
//     /**
//      * @dev Duyệt hàng loạt yêu cầu tích điểm
//      */
//     function batchApproveRequests(uint256[] calldata _requestIds) external onlyAdmin {
//         for (uint256 i = 0; i < _requestIds.length; i++) {
//             uint256 requestId = _requestIds[i];
//             ManualRequest storage request = manualRequests[requestId];
            
//             if (
//                 request.status == RequestStatus.Pending && 
//                 !processedInvoices[request.invoiceId]
//             ) {
//                 Member storage member = members[request.member];
                
//                 uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//                 uint256 points = (request.pointsToEarn * tierMultiplier) / 100;
                
//                 member.totalPoints += points;
//                 member.lifetimePoints += points;
//                 member.totalSpent += request.amount;
//                 // member.lastBuyActivityAt = block.timestamp;
                
//                 request.status = RequestStatus.Approved;
//                 request.approvedBy = msg.sender;
//                 request.approvedTime = block.timestamp;
                
//                 processedInvoices[request.invoiceId] = true;
                
//                 _updateMemberTier(request.member);
                
//                 // _createTransaction(
//                 //     request.member,
//                 //     TransactionType.Earn,
//                 //     int256(points),
//                 //     request.amount,
//                 //     request.invoiceId,
//                 //     request.note,
//                 //     0
//                 // );
                
//                 totalPointsIssued += points;
                
//                 emit ManualRequestProcessed(requestId, true, msg.sender, block.timestamp);
//             }
//         }
//     }
    
//     // ============ INTERNAL FUNCTIONS ============
    
//     /**
//      * @dev Tạo giao dịch mới
//      */
//     function _createTransaction(
//         address _member,
//         TransactionType _txType,
//         int256 _points,
//         uint256 _amount,
//         bytes32  _invoiceId,
//         string memory _note,
//         uint256 _eventId
//     ) internal {
//         transactionCounter++;
//         transactions[transactionCounter] = Transaction({
//             id: transactionCounter,
//             member: _member,
//             txType: _txType,
//             points: _points,
//             amount: _amount,
//             invoiceId: _invoiceId,
//             processedBy: msg.sender,
//             timestamp: block.timestamp,
//             note: _note,
//             eventId: _eventId,
//             status: PointTransactionStatus.Completed
//         });
        
//         memberTransactions[_member].push(transactionCounter);
//         allTransactions.push(transactions[transactionCounter]);
//         emit TransactionCreated(transactionCounter, _member, _txType, _points);
//     }
//     function GetAllTransactionsPaginationByType(
//         uint256 offset, 
//         uint256 limit,
//         TransactionType _txType
//     )
//         external
//         view
//         returns (Transaction[] memory result,uint totalCount)
//     {
//         uint count = 0;
//         for(uint i; i< allTransactions.length;i++){
//             Transaction memory transaction = allTransactions[i];
//             if(transaction.txType == _txType){
//                 count++;
//             }
//         }
//         totalCount = count;
//         Transaction[] memory transactionArr= new Transaction[](count);
//         uint index = 0;
//         for(uint i; i< allTransactions.length;i++){
//             Transaction memory transaction = allTransactions[i];
//             if(transaction.txType == _txType){
//                 transactionArr[index] = transaction;
//                 index++;
//             }
//         }
//         if(offset >= count) {
//             return ( new Transaction[](0),count);
//         }

//         uint256 end = offset + limit;
//         if (end > count) {
//             end = count;
//         }

//         uint256 size = end - offset;
//         result = new Transaction[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = count - 1 - offset - i;
//             result[i] = transactionArr[reverseIndex];
//         }

//         return (result,count);
//     }


//     function GetAllTransactionsPagination(
//         uint256 offset, 
//         uint256 limit
//     )
//         external
//         view
//         returns (Transaction[] memory result,uint totalCount)
//     {
//         uint length = allTransactions.length;
//         if(offset >= length) {
//             return ( new Transaction[](0),length);
//         }

//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         result = new Transaction[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = length - 1 - offset - i;
//             result[i] = allTransactions[reverseIndex];
//         }

//         return (result,length);
//     }
// /**
//  * @dev Lấy transactions của member theo pagination
//  */
// function getMemberTransactionsPagination(
//     address _member,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     Transaction[] memory result,
//     uint256 totalCount
// ) {
//     uint256[] memory txIds = memberTransactions[_member];
//     uint256 length = txIds.length;
    
//     if (offset >= length) {
//         return (new Transaction[](0), length);
//     }
    
//     uint256 end = offset + limit;
//     if (end > length) {
//         end = length;
//     }
    
//     uint256 size = end - offset;
//     result = new Transaction[](size);
    
//     // Lấy transactions theo thứ tự đảo ngược (mới nhất trước)
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = length - 1 - offset - i;
//         uint256 txId = txIds[reverseIndex];
//         result[i] = transactions[txId];
//     }
    
//     return (result, length);
// }
//     /**
//      * @dev Cập nhật hạng thành viên
//      */
//     function _updateMemberTier(address _member) internal {
//         Member storage member = members[_member];
//         bytes32 oldTierID = member.tierID;
//         bytes32 newTierID = _calculateTier(member.lifetimePoints);
        
//         if (newTierID != oldTierID) {
//             member.tierID = newTierID;
//             // member.tierUpdatedAt = block.timestamp;
            
//             emit TierUpdated(_member, uint256(uint160(address(uint160(uint256(oldTierID))))), 
//                             uint256(uint160(address(uint160(uint256(newTierID))))), block.timestamp);
//         }
//     }
   
//     /**
//      * @dev Tính hạng thành viên dựa trên điểm tích lũy
//      */
// function _calculateTier(uint256 _lifetimePoints) internal view returns (bytes32) {
//     // Duyệt qua các tier theo thứ tự đã sắp xếp (từ thấp đến cao)
//     bytes32 currentTierID = bytes32(0); // None tier
    
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         TierConfig memory tier = allTiers[i];
        
//         // Kiểm tra điểm có nằm trong khoảng [pointsRequired, pointsMax)
//         if (_lifetimePoints >= tier.pointsRequired && _lifetimePoints < tier.pointsMax) {
//             return tier.id;
//         }
//     }
    
//     return currentTierID; // Trả về None nếu không thuộc tier nào
// }
    
//     /**
//      * @dev Lấy hệ số thưởng theo hạng
//      */
//    function _getTierMultiplier(bytes32 _tierID) internal view returns (uint256) {
//     if (_tierID == bytes32(0)) {
//         return 100; // 1x cho None tier
//     }
    
//     TierConfig storage config = tierConfigs[_tierID];
//     if (config.id == bytes32(0)) {
//         return 100; // Default 1x nếu tier không tồn tại
//     }
    
//     return config.multiplier;
// }
    
//     /**
//      * @dev Kiểm tra sự kiện đang hoạt động
//      */
//     function _getActiveEvent(bytes32 _memberTierID) internal view returns (uint256) {
//         uint256 memberTierLevel = _getTierLevel(_memberTierID);
//         for (uint256 i = 1; i <= eventCounter; i++) {
//             Event storage evt = events[i];
//             uint256 eventMinTierLevel = _getTierLevel(evt.minTierID);

//             if (
//                 evt.isActive &&
//                 block.timestamp >= evt.startTime &&
//                 block.timestamp <= evt.endTime &&
//                 memberTierLevel >= eventMinTierLevel
//             ) {
//                 return evt.id;
//             }
//         }
//         return 0;
//     }
//     // Hàm helper để so sánh tier level:
//     function _getTierLevel(bytes32 _tierID) internal view returns (uint256) {
//         if (_tierID == bytes32(0)) return 0;
        
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             if (allTiers[i].id == _tierID) {
//                 return i + 1; // Level bắt đầu từ 1
//             }
//         }
//         return 0;
//     }
//     // ============ VIEW FUNCTIONS ============
    
//     /**
//      * @dev Lấy thông tin thành viên
//      */
//     function getMember(address _member) external view returns (
//         string memory memberId,
//         uint256 totalPoints,
//         uint256 lifetimePoints,
//         uint256 totalSpent,
//         bytes32 tierID,
//         string memory tierName,
//         bool isActive,
//         bool isLocked,
//         uint256 lastBuyActivityAt,
//         string memory phoneNumber,
//         string memory email,
//         string memory avatar
//     ) {
//         Member storage member = members[_member];
//         string memory tName = "";
        
//         if (member.tierID != bytes32(0)) {
//             tName = tierConfigs[member.tierID].nameTier;
//         }       
//          return (
//             member.memberId,
//             member.totalPoints,
//             member.lifetimePoints,
//             member.totalSpent,
//             member.tierID,
//             tName,
//             member.isActive,
//             member.isLocked,
//             member.lastBuyActivityAt,
//             member.phoneNumber,
//             member.email,
//             member.avatar
//         );
//     }
//     function getEachMember(address _member) external view returns (Member memory){
//         return members[_member];
//     }
//     /**
//      * @dev Lấy thông tin thành viên theo Member ID
//      */
//     function getMemberByMemberId(string memory _memberId) external view returns (
//         address walletAddress,
//         uint256 totalPoints,
//         uint256 lifetimePoints,
//         bytes32 tierID,
//         bool isActive,
//         bool isLocked
//     ) {
//         address wallet = memberIdToAddress[_memberId];
//         require(wallet != address(0), "Member not found");
        
//         Member storage member = members[wallet];
//         return (
//             member.walletAddress,
//             member.totalPoints,
//             member.lifetimePoints,
//             member.tierID,
//             member.isActive,
//             member.isLocked
//         );
//     }
    
//     /**
//      * @dev Lấy lịch sử giao dịch của thành viên
//      */
//     function getMemberTransactions(address _member) external view returns (uint256[] memory) {
//         return memberTransactions[_member];
//     }
    
// /**
//  * @dev Lấy transactions của member trong khoảng thời gian với pagination
//  */
// function getMemberTransactionsByDateRange(
//     address _member,
//     uint256 _startTime,
//     uint256 _endTime,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     Transaction[] memory result,
//     uint256 totalCount
// ) {
//     require(_startTime <= _endTime, "Invalid time range");
    
//     uint256[] memory txIds = memberTransactions[_member];
    
//     uint256 count = 0;
//     for (uint256 i = 0; i < txIds.length; i++) {
//         Transaction memory tx = transactions[txIds[i]];
//         if (tx.timestamp >= _startTime && tx.timestamp <= _endTime) {
//             count++;
//         }
//     }
    
//     if (count == 0 || offset >= count) {
//         return (new Transaction[](0), count);
//     }
    
//     Transaction[] memory filtered = new Transaction[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 0; i < txIds.length; i++) {
//         uint256 reverseIndex = txIds.length - 1 - i;
//         uint256 txId = txIds[reverseIndex];
//         Transaction memory tx = transactions[txId];
        
//         if (tx.timestamp >= _startTime && tx.timestamp <= _endTime) {
//             filtered[index] = tx;
//             index++;
//         }
//     }
    
//     uint256 end = offset + limit;
//     if (end > count) {
//         end = count;
//     }
    
//     uint256 size = end - offset;
//     result = new Transaction[](size);
    
//     for (uint256 i = 0; i < size; i++) {
//         result[i] = filtered[offset + i];
//     }
    
//     return (result, count);
// }
//     /**
//      * @dev Lấy chi tiết giao dịch
//      */
//     function getTransaction(uint256 _txId) external view returns (
//         address member,
//         TransactionType txType,
//         int256 points,
//         uint256 amount,
//         bytes32 invoiceId,
//         uint256 timestamp,
//         string memory note
//     ) {
//         Transaction storage _tx = transactions[_txId];
//         return (
//             _tx.member,
//             _tx.txType,
//             _tx.points,
//             _tx.amount,
//             _tx.invoiceId,
//             _tx.timestamp,
//             _tx.note
//         );
//     }
    
//     /**
//      * @dev Lấy thông tin sự kiện
//      */
//     function getEvent(uint256 _eventId) external view returns (
//         string memory name,
//         uint256 startTime,
//         uint256 endTime,
//         uint256 pointPlus,
//         bytes32 minTier,
//         bool isActive
//     ) {
//         Event storage evt = events[_eventId];
//         return (
//             evt.name,
//             evt.startTime,
//             evt.endTime,
//             evt.pointPlus,
//             evt.minTierID,
//             evt.isActive
//         );
//     }
    
//     /**
//      * @dev Lấy danh sách sự kiện đang hoạt động
//      */
//     function getActiveEvents() external view returns (uint256[] memory) {
//         uint256[] memory activeEventIds = new uint256[](eventCounter);
//         uint256 count = 0;
        
//         for (uint256 i = 1; i <= eventCounter; i++) {
//             Event storage evt = events[i];
//             if (
//                 evt.isActive &&
//                 block.timestamp >= evt.startTime &&
//                 block.timestamp <= evt.endTime
//             ) {
//                 activeEventIds[count] = evt.id;
//                 count++;
//             }
//         }
        
//         // Tạo mảng với kích thước chính xác
//         uint256[] memory result = new uint256[](count);
//         for (uint256 i = 0; i < count; i++) {
//             result[i] = activeEventIds[i];
//         }
        
//         return result;
//     }
    
//     // /**
//     //  * @dev Lấy thông tin quà tặng
//     //  */
//     // function getReward(uint256 _rewardId) external view returns (
//     //     string memory name,
//     //     uint256 pointsCost,
//     //     bytes32 minTier,
//     //     uint256 quantity,
//     //     bool isActive
//     // ) {
//     //     Reward storage reward = rewards[_rewardId];
//     //     return (
//     //         reward.name,
//     //         reward.pointsCost,
//     //         reward.minTierID,
//     //         reward.quantity,
//     //         reward.isActive
//     //     );
//     // }
    
//     // /**
//     //  * @dev Lấy danh sách quà tặng khả dụng
//     //  */
//     // function getAvailableRewards() external view returns (uint256[] memory) {
//     //     uint256[] memory availableRewardIds = new uint256[](rewardCounter);
//     //     uint256 count = 0;
        
//     //     for (uint256 i = 1; i <= rewardCounter; i++) {
//     //         Reward storage reward = rewards[i];
//     //         if (reward.isActive && reward.quantity > 0) {
//     //             availableRewardIds[count] = reward.id;
//     //             count++;
//     //         }
//     //     }
        
//     //     uint256[] memory result = new uint256[](count);
//     //     for (uint256 i = 0; i < count; i++) {
//     //         result[i] = availableRewardIds[i];
//     //     }
        
//     //     return result;
//     // }
    

    
//     /**
//      * @dev Lấy thông tin yêu cầu tích điểm thủ công
//      */
//     function getManualRequest(uint256 _requestId) external view returns (
//         address member,
//         bytes32 invoiceId,
//         uint256 amount,
//         uint256 pointsToEarn,
//         address requestedBy,
//         RequestStatus status,
//         RequestEarnPointType typeRequest
//     ) {
//         ManualRequest storage request = manualRequests[_requestId];
//         return (
//             request.member,
//             request.invoiceId,
//             request.amount,
//             request.pointsToEarn,
//             request.requestedBy,
//             request.status,
//             request.typeRequest
//         );
//     }
    
//     /**
//      * @dev Lấy danh sách yêu cầu đang chờ duyệt
//      */
//     function getRequestsByStatusPagination(
//         RequestStatus _requestStatus, 
//         uint offset, 
//         uint limit
//     ) external view returns (ManualRequest[] memory, uint totalCount) {
        
//         uint256 count = 0;
        
//         for (uint256 i = 1; i <= requestCounter; i++) {
//             if (manualRequests[i].status == _requestStatus) {
//                 count++;
//             }
//         }
//         ManualRequest[] memory requests = new ManualRequest[](count);
//         uint256 index = 0;
//         for (uint256 i = 1; i <= requestCounter; i++) {
//             if (manualRequests[i].status == _requestStatus) {
//                 requests[index] = manualRequests[i];
//                 index++;
//             }
//         }
//         if(offset > count) return (new ManualRequest[](0),count);
        
//         uint end = offset + limit;
//         if(end > count) end = count;
//         uint size = end - offset;
//         ManualRequest[] memory result = new ManualRequest[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = requests.length - 1 - offset - i;
//             result[i] = requests[reverseIndex];
//         }

//         return (result,count);
//     }
    
//     /**
//      * @dev Kiểm tra hóa đơn đã được xử lý chưa
//      */
//     function isInvoiceProcessed(bytes32 _invoiceId) external view returns (bool) {
//         return processedInvoices[_invoiceId];
//     }
    
//     /**
//      * @dev Lấy số lượng yêu cầu hàng ngày của nhân viên
//      */
//     function getStaffDailyRequests(address _staff) external view returns (uint256) {
//         if (block.timestamp / 1 days > lastRequestDate[_staff] / 1 days) {
//             return 0;
//         }
//         return staffDailyRequests[_staff];
//     }
    
//     /**
//      * @dev Lấy tổng số thành viên theo hạng
//      */
//     function getMemberCountByTier(bytes32 _tierID) external view returns (uint256) {
//         uint256 count = 0;
        
//         // Duyệt qua tất cả members trong allMembers
//         for (uint256 i = 0; i < allMembers.length; i++) {
//             Member memory member = allMembers[i];
            
//             // Chỉ đếm member đang active và có tierID khớp
//             if (member.isActive && member.tierID == _tierID) {
//                 count++;
//             }
//         }
        
//         return count;
//     }
//     // Thêm hàm lấy thống kê tất cả tier:
//     function getAllTiersWithMemberCount() external view returns (
//         TierConfig[] memory tiers,
//         uint256[] memory memberCounts
//     ) {
//         tiers = allTiers;
//         memberCounts = new uint256[](allTiers.length);
        
//         // Đếm members cho từng tier
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             uint256 count = 0;
//             bytes32 tierID = allTiers[i].id;
            
//             for (uint256 j = 0; j < allMembers.length; j++) {
//                 if (allMembers[j].isActive && allMembers[j].tierID == tierID) {
//                     count++;
//                 }
//             }
            
//             memberCounts[i] = count;
//         }
        
//         return (tiers, memberCounts);
//     }

//     // Thêm hàm lấy số member None tier (không thuộc tier nào):
//     function getNoneTierMemberCount() external view returns (uint256) {
//         uint256 count = 0;
        
//         for (uint256 i = 0; i < allMembers.length; i++) {
//             Member memory member = allMembers[i];
            
//             if (member.isActive && member.tierID == bytes32(0)) {
//                 count++;
//             }
//         }
        
//         return count;
//     }
    
//         /**
//         * @dev Lấy thống kê tổng quan hệ thống
//         */
//         function getSystemStats() external view returns (
//             uint256 totalPointApprovedKq,
//             uint256 totalIssued,
//             uint256 totalRedeemed,
//             uint256 totalMembers,
//             uint256 totalTransactions,
//             uint256 totalEvents,
//             uint256 totalRewards
//         ) {
//             return (
//                 totalPointApprovedKq,
//                 totalPointsIssued,
//                 totalPointsRedeemed,
//                 0, // Cần implement counter riêng cho members
//                 transactionCounter,
//                 eventCounter,
//                 rewardCounter
//             );
//         }
        
//         /**
//         * @dev Tính điểm sẽ nhận được từ số tiền thanh toán
//         */
//         function calculatePointsFromAmount(
//             uint256 _amount,
//             address _member,
//             uint256 _eventId
//         ) external view returns (uint256) {
//             uint256  amountAfter = _amount * accumulationPercent;
//             uint256 basePoints = amountAfter / exchangeRate;
            
//             if (!members[_member].isActive) {
//                 return basePoints;
//             }
            
//             Member storage member = members[_member];
//             uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//             uint256 points = (basePoints * tierMultiplier) / 100;
            
//             if (_eventId > 0){
//                 require(_isEventValidForMember(_eventId, member.tierID), "Event not valid for this member");
//                 Event storage evt = events[_eventId];
//                 points = points + evt.pointPlus;
                            
//             }            
//             return points;
//         }

//     //     /**
//     //     * @dev Kiểm tra xem thành viên có đủ điều kiện đổi quà không
//     //     */
//     // function canRedeemReward(address _member, uint256 _rewardId) external view returns (
//     //     bool canRedeem,
//     //     string memory reason
//     // ) {
//     //     // Kiểm tra member tồn tại và active
//     //     if (!members[_member].isActive) {
//     //         return (false, "Member not active");
//     //     }
        
//     //     if (members[_member].isLocked) {
//     //         return (false, "Account is locked");
//     //     }
        
//     //     Member storage member = members[_member];
//     //     Reward storage reward = rewards[_rewardId];
        
//     //     // Kiểm tra reward tồn tại
//     //     if (reward.id == 0) {
//     //         return (false, "Reward not found");
//     //     }
        
//     //     // Kiểm tra reward active
//     //     if (!reward.isActive) {
//     //         return (false, "Reward not active");
//     //     }
        
//     //     // Kiểm tra số lượng
//     //     if (reward.quantity == 0) {
//     //         return (false, "Reward out of stock");
//     //     }
        
//     //     // Kiểm tra điểm
//     //     if (member.totalPoints < reward.pointsCost) {
//     //         return (false, "Insufficient points");
//     //     }
        
//     //     // Kiểm tra tier requirement
//     //     uint256 memberTierLevel = _getTierLevel(member.tierID);
//     //     uint256 rewardMinTierLevel = _getTierLevel(reward.minTierID);
        
//     //     if (memberTierLevel < rewardMinTierLevel) {
//     //         return (false, "Tier requirement not met");
//     //     }
        
//     //     return (true, "Can redeem");
//     // }
//     /**
//     * @dev Member đổi điểm lấy voucher
//     */
//     function redeemVoucher(
//         string memory _voucherCode
//     ) external memberExists(msg.sender) notLocked(msg.sender) nonReentrant {
//         Member storage member = members[msg.sender];
        
//         // Lấy thông tin voucher từ Management contract
//         Discount memory discount = MANAGEMENT.GetDiscount(_voucherCode);
        
//         require(bytes(discount.code).length > 0, "Voucher not found");
//         require(discount.active, "Voucher inactive");
//         require(discount.isRedeemable, "Voucher not redeemable with points");
//         require(discount.pointCost > 0, "Invalid point cost");
//         require(block.timestamp >= discount.from && block.timestamp <= discount.to, "Voucher expired");
//         require(discount.amountUsed < discount.amountMax, "Voucher limit reached");
//         require(discount.discountType == DiscountType.AUTO_ALL,"Only voucher Auto-All type can be redeemed ");
//         // // Kiểm tra member chưa redeem voucher này
//         // require(!memberVoucherRedeemed[msg.sender][_voucherCode], "Already redeemed this voucher");
        
//         // Kiểm tra đủ điểm
//         require(member.totalPoints >= discount.pointCost, "Insufficient points");
        
//         // Trừ điểm
//         member.totalPoints -= discount.pointCost;
        
//         // Kiểm tra xem đã có voucher code này trong danh sách chưa
//         bool codeExists = false;
//         for (uint256 i = 0; i < memberVouchers[msg.sender].length; i++) {
//             if (keccak256(bytes(memberVouchers[msg.sender][i])) == keccak256(bytes(_voucherCode))) {
//                 codeExists = true;
//                 break;
//             }
//         }
        
//         // Nếu chưa có, thêm vào danh sách codes
//         if (!codeExists) {
//             memberVouchers[msg.sender].push(_voucherCode);
//         }        
            
//         // Lưu chi tiết voucher
//         memberVoucherDetails[msg.sender][_voucherCode].push(MemberVoucher({
//             code: _voucherCode,
//             redeemedAt: block.timestamp,
//             isUsed: false,
//             usedAt: 0,
//             voucherDetail: discount
//         }));
        
//         // Ghi nhận giao dịch
//         _createTransaction(
//             msg.sender,
//             TransactionType.Redeem,
//             -int256(discount.pointCost),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Redeem voucher: ", _voucherCode)),
//             0
//         );
        
//         totalPointsRedeemed += discount.pointCost;
        
//         emit VoucherRedeemed(msg.sender, _voucherCode, discount.pointCost, block.timestamp);
//     }

//     /**
//     * @dev Đánh dấu voucher đã sử dụng (gọi từ Order contract)
//     */
//     function markVoucherAsUsed(
//         address _member,
//         string memory _voucherCode
//     ) external onlyOrder {
//         // Chỉ Order contract mới được gọi
//         require(msg.sender == address(MANAGEMENT) || MANAGEMENT.hasRole(ROLE_ADMIN, msg.sender), "Unauthorized");
        
//     MemberVoucher[] storage vouchers = memberVoucherDetails[_member][_voucherCode];
//         require(vouchers.length > 0, "No voucher found with this code");
        
//         // Tìm voucher chưa dùng đầu tiên
//         bool found = false;
//         for (uint256 i = 0; i < vouchers.length; i++) {
//             if (!vouchers[i].isUsed) {
//                 vouchers[i].isUsed = true;
//                 vouchers[i].usedAt = block.timestamp;
//                 found = true;
//                 emit VoucherUsed(_member, _voucherCode, block.timestamp);
//                 break;
//             }
//         }
        
//         require(found, "No unused voucher available");   
//     }

//     // /**
//     // * @dev Kiểm tra member có thể redeem voucher không
//     // */
//     // function canRedeemVoucher(
//     //     address _member,
//     //     string memory _voucherCode
//     // ) external view returns (
//     //     bool canRedeem,
//     //     string memory reason,
//     //     uint256 pointsRequired
//     // ) {
//     //     if (!members[_member].isActive) {
//     //         return (false, "Member not active", 0);
//     //     }
        
//     //     if (members[_member].isLocked) {
//     //         return (false, "Account is locked", 0);
//     //     }
        
//     //     Member storage member = members[_member];
//     //     Discount memory discount = MANAGEMENT.GetDiscount(_voucherCode);
        
//     //     if (bytes(discount.code).length == 0) {
//     //         return (false, "Voucher not found", 0);
//     //     }
        
//     //     if (!discount.active) {
//     //         return (false, "Voucher inactive", discount.pointCost);
//     //     }
        
//     //     if (!discount.isRedeemable) {
//     //         return (false, "Voucher not redeemable with points", discount.pointCost);
//     //     }
        
//     //     if (discount.pointCost == 0) {
//     //         return (false, "Invalid point cost", 0);
//     //     }
        
//     //     if (block.timestamp < discount.from || block.timestamp > discount.to) {
//     //         return (false, "Voucher expired", discount.pointCost);
//     //     }
        
//     //     if (discount.amountUsed >= discount.amountMax) {
//     //         return (false, "Voucher limit reached", discount.pointCost);
//     //     }
        
//     //     if (memberVoucherRedeemed[_member][_voucherCode]) {
//     //         return (false, "Already redeemed this voucher", discount.pointCost);
//     //     }
        
//     //     if (member.totalPoints < discount.pointCost) {
//     //         return (false, "Insufficient points", discount.pointCost);
//     //     }
        
//     //     return (true, "Can redeem", discount.pointCost);
//     // }

//     // /**
//     // * @dev Lấy danh sách voucher của member
//     // */
//     // function getMemberVouchers(address _member) external view returns (
//     //     string[] memory codes,
//     //     MemberVoucher[] memory voucherDetails
//     // ) {
//     //     codes = memberVouchers[_member];
//     //     voucherDetails = new MemberVoucher[](codes.length);
        
//     //     for (uint256 i = 0; i < codes.length; i++) {
//     //         voucherDetails[i] = memberVoucherDetails[_member][codes[i]];
//     //     }
        
//     //     return (codes, voucherDetails);
//     // }

//     /**
//     * @dev Lấy danh sách voucher của member với pagination
//     */
//     function getMemberVouchersPagination(
//         address _member,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (
//         MemberVoucher[] memory result,
//         uint256 totalCount
//     ) {
//         string[] memory codes = memberVouchers[_member];
        
//         // Đếm tổng số vouchers (có thể có nhiều voucher cùng code)
//         uint256 count = 0;
//         for (uint256 i = 0; i < codes.length; i++) {
//             count += memberVoucherDetails[_member][codes[i]].length;
//         }
        
//         if (count == 0 || offset >= count) {
//             return (new MemberVoucher[](0), count);
//         }
        
//         // Tạo mảng tất cả vouchers
//         MemberVoucher[] memory allVouchers = new MemberVoucher[](count);
//         uint256 index = 0;
//         for (uint256 i = 0; i < codes.length; i++) {
//             MemberVoucher[] memory vouchersForCode = memberVoucherDetails[_member][codes[i]];
//             for (uint256 j = 0; j < vouchersForCode.length; j++) {
//                 allVouchers[index] = vouchersForCode[j];
//                 index++;
//             }
//         }
        
//         // Pagination
//         uint256 end = offset + limit;
//         if (end > count) {
//             end = count;
//         }
        
//         uint256 size = end - offset;
//         result = new MemberVoucher[](size);
        
//         // Lấy từ mới nhất (reverse order)
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = count - 1 - offset - i;
//             result[i] = allVouchers[reverseIndex];
//         }
        
//         return (result, count);    
//     }

// /**
//  * @dev Lấy danh sách voucher CHƯA SỬ DỤNG của member với pagination
//  */
// function getUnusedVouchersPagination(
//     address _member,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     MemberVoucher[] memory result,
//     uint256 totalCount
// ) {
//     string[] memory codes = memberVouchers[_member];
    
//     // Đếm số vouchers chưa dùng
//     uint256 count = 0;
//     for (uint256 i = 0; i < codes.length; i++) {
//         MemberVoucher[] memory vouchersForCode = memberVoucherDetails[_member][codes[i]];
//         for (uint256 j = 0; j < vouchersForCode.length; j++) {
//             if (!vouchersForCode[j].isUsed) {
//                 count++;
//             }
//         }
//     }
    
//     if (count == 0 || offset >= count) {
//         return (new MemberVoucher[](0), count);
//     }
    
//     // Tạo mảng vouchers chưa dùng
//     MemberVoucher[] memory unusedVouchers = new MemberVoucher[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 0; i < codes.length; i++) {
//         MemberVoucher[] memory vouchersForCode = memberVoucherDetails[_member][codes[i]];
//         for (uint256 j = 0; j < vouchersForCode.length; j++) {
//             if (!vouchersForCode[j].isUsed) {
//                 unusedVouchers[index] = vouchersForCode[j];
//                 index++;
//             }
//         }
//     }
    
//     // Pagination
//     uint256 end = offset + limit;
//     if (end > count) {
//         end = count;
//     }
    
//     uint256 size = end - offset;
//     result = new MemberVoucher[](size);
    
//     // Lấy từ mới nhất (reverse order)
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = count - 1 - offset - i;
//         result[i] = unusedVouchers[reverseIndex];
//     }
    
//     return (result, count);
// }
//     // /**
//     // * @dev Lấy danh sách voucher có thể redeem
//     // */
//     // function getRedeemableVouchers(address _member) external view returns (
//     //     Discount[] memory vouchers
//     // ) {
//     //     Member storage member = members[_member];
//     //     Discount[] memory allDiscounts = MANAGEMENT.GetAllDiscounts();
        
//     //     // Đếm số voucher có thể redeem
//     //     uint256 count = 0;
//     //     for (uint256 i = 0; i < allDiscounts.length; i++) {
//     //         Discount memory discount = allDiscounts[i];
            
//     //         if (
//     //             discount.isRedeemable &&
//     //             discount.active &&
//     //             discount.pointCost > 0 &&
//     //             discount.pointCost <= member.totalPoints &&
//     //             block.timestamp >= discount.from &&
//     //             block.timestamp <= discount.to &&
//     //             discount.amountUsed < discount.amountMax &&
//     //             !memberVoucherRedeemed[_member][discount.code]
//     //         ) {
//     //             count++;
//     //         }
//     //     }
        
//     //     vouchers = new Discount[](count);
//     //     uint256 index = 0;
        
//     //     for (uint256 i = 0; i < allDiscounts.length; i++) {
//     //         Discount memory discount = allDiscounts[i];
            
//     //         if (
//     //             discount.isRedeemable &&
//     //             discount.active &&
//     //             discount.pointCost > 0 &&
//     //             discount.pointCost <= member.totalPoints &&
//     //             block.timestamp >= discount.from &&
//     //             block.timestamp <= discount.to &&
//     //             discount.amountUsed < discount.amountMax &&
//     //             !memberVoucherRedeemed[_member][discount.code]
//     //         ) {
//     //             vouchers[index] = discount;
//     //             index++;
//     //         }
//     //     }
        
//     //     return vouchers;
//     // }

//     // /**
//     // * @dev Kiểm tra voucher có hợp lệ để sử dụng không
//     // */
//     // function isVoucherValidForUse(
//     //     address _member,
//     //     string memory _voucherCode
//     // ) external view returns (
//     //     bool isValid,
//     //     string memory reason
//     // ) {
//     //     // Check member đã redeem voucher này chưa
//     //     if (!memberVoucherRedeemed[_member][_voucherCode]) {
//     //         return (false, "Voucher not redeemed by member");
//     //     }
        
//     //     // Check voucher đã dùng chưa
//     //     if (memberVoucherDetails[_member][_voucherCode].isUsed) {
//     //         return (false, "Voucher already used");
//     //     }
        
//     //     // Check voucher còn trong thời hạn không
//     //     Discount memory discount = MANAGEMENT.GetDiscount(_voucherCode);
//     //     if (block.timestamp > discount.to) {
//     //         return (false, "Voucher expired");
//     //     }
        
//     //     return (true, "Valid");
//     // }
//     // ============ PAYMENT FUNCTIONS ============

// /**
//  * @dev Sử dụng points để thanh toán order
//  */
// function usePointsForPayment(
//     address _member,
//     uint256 _pointsToUse,
//     uint256 _orderAmount
// ) external memberExists(_member) notLocked(_member) {
//     // Chỉ Order contract mới được gọi
//     require(msg.sender == address(MANAGEMENT) || MANAGEMENT.hasRole(ROLE_ADMIN, msg.sender), "Unauthorized");
    
//     Member storage member = members[_member];
//     require(member.totalPoints >= _pointsToUse, "Insufficient points");
    
//     // Trừ điểm
//     member.totalPoints -= _pointsToUse;
//     member.lastBuyActivityAt = block.timestamp;
    
//     // Tạo giao dịch
//     bytes32 paymentId = keccak256(abi.encodePacked(_member, _pointsToUse, block.timestamp));
    
//     _createTransaction(
//         _member,
//         TransactionType.Redeem,
//         -int256(_pointsToUse),
//         _orderAmount,
//         paymentId,
//         string(abi.encodePacked("Payment with points: ", _pointsToUse.toString())),
//         0
//     );
    
//     // Lưu lịch sử thanh toán
//     memberPaymentHistory[_member].push(PaymentTransaction({
//         paymentId: paymentId,
//         pointsUsed: _pointsToUse,
//         orderAmount: _orderAmount,
//         timestamp: block.timestamp
//     }));
    
//     totalPointsRedeemed += _pointsToUse;
    
//     emit PointsUsedForPayment(_member, paymentId, _pointsToUse, _orderAmount, block.timestamp);
// }

// /**
//  * @dev Lấy lịch sử thanh toán bằng points của member
//  */
// function getMemberPaymentHistory(
//     address _member,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     PaymentTransaction[] memory result,
//     uint256 totalCount
// ) {
//     PaymentTransaction[] memory history = memberPaymentHistory[_member];
//     uint256 length = history.length;
    
//     if (offset >= length) {
//         return (new PaymentTransaction[](0), length);
//     }
    
//     uint256 end = offset + limit;
//     if (end > length) {
//         end = length;
//     }
    
//     uint256 size = end - offset;
//     result = new PaymentTransaction[](size);
    
//     // Lấy từ mới nhất (reverse order)
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = length - 1 - offset - i;
//         result[i] = history[reverseIndex];
//     }
    
//     return (result, length);
// }

// /**
//  * @dev Tính toán số points cần để thanh toán một số tiền
//  */
// function calculatePointsNeeded(uint256 _amount) external view returns (uint256) {
//     if (exchangeRate == 0) return 0;
//     return _amount / exchangeRate;
// }

// /**
//  * @dev Tính toán giá trị tiền của số points
//  */
// function calculatePointsValue(uint256 _points) external view returns (uint256) {
//     return _points * exchangeRate;
// }

// /**
//  * @dev Kiểm tra member có đủ points để thanh toán không
//  */
// function canPayWithPoints(
//     address _member,
//     uint256 _amount
// ) external view returns (
//     bool canPay,
//     uint256 pointsNeeded,
//     uint256 currentPoints,
//     uint256 maxPayableAmount
// ) {
//     if (!members[_member].isActive) {
//         return (false, 0, 0, 0);
//     }
    
//     Member storage member = members[_member];
    
//     if (member.isLocked) {
//         return (false, 0, member.totalPoints, 0);
//     }
    
//     maxPayableAmount = (_amount * maxPercentPerInvoice) / 100;
//     pointsNeeded = maxPayableAmount / exchangeRate;
//     currentPoints = member.totalPoints;
    
//     canPay = (currentPoints >= pointsNeeded);
    
//     return (canPay, pointsNeeded, currentPoints, maxPayableAmount);
// }

// /**
//  * @dev Hoàn points khi hủy/hoàn order
//  */
// function refundPaymentPoints(
//     address _member,
//     bytes32 _paymentId,
//     uint256 _pointsToRefund,
//     string memory _reason
// ) external onlyAdmin memberExists(_member) {
//     require(_pointsToRefund > 0, "Invalid points amount");
    
//     Member storage member = members[_member];
    
//     // Hoàn điểm
//     member.totalPoints += _pointsToRefund;
//     // member.lastActivityAt = block.timestamp;
    
//     // Tạo giao dịch hoàn điểm
//     _createTransaction(
//         _member,
//         TransactionType.Refund,
//         int256(_pointsToRefund),
//         0,
//         _paymentId,
//         _reason,
//         0
//     );
    
//     emit PointsRefunded(_member, _pointsToRefund, _paymentId, _reason, block.timestamp);
// }
// }       
