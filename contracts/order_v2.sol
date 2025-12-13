// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.20;
// import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./interfaces/IManagement.sol";
// import "./interfaces/INoti.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "./interfaces/IReport.sol";
// import "./interfaces/IAgent.sol";
// import "./interfaces/IPoint.sol";

// interface IIQRAgent {
//     function createOrder(
//         bytes32 _paymentId,
//         uint256 _amount
//     ) external ;
// }

// contract RestaurantOrder is 
//     Initializable, 
//     ReentrancyGuardUpgradeable, 
//     OwnableUpgradeable, 
//     PausableUpgradeable, 
//     UUPSUpgradeable  
// {
//     using Strings for uint256;

//     // State variables
//     IManagement public MANAGEMENT;
//     IERC20 public SCUsdt;
//     ICardTokenManager public ICARD_VISA;
    
//     address public MasterPool;
//     address public merchant;
//     uint8 public taxPercent;

//     // Core mappings
//     mapping(uint => Order[]) public tableOrders;
//     mapping(uint => SimpleCourse[]) public mTableToCourses;
//     mapping(uint => Payment) public mTableToPayment;
//     mapping(bytes32 => Payment) public mIdToPayment;
//     mapping(bytes32 => SimpleCourse[]) public paymentCourses;
//     mapping(bytes32 => Review) public reviews;
//     mapping(string => DishReview[]) public mDishCodeToReviews;
//     mapping(address => mapping(string => uint)) public customerDishCounts;
//     mapping(string => bool) public usedTxIds;
//     mapping(bytes32 => SimpleCourse[]) public mOrderIdToCourses;
//     mapping(uint => mapping(uint => SimpleCourse)) public mTableToIdToCourse;

//     // NEW: Staff assignment và transfer tracking
//     mapping(bytes32 => address) public orderPrimaryStaff; // orderId => staff đang phụ trách
//     mapping(bytes32 => address[]) public orderStaffHistory; // orderId => lịch sử staff phục vụ
//     mapping(bytes32 => mapping(address => uint8)) public orderStaffShare; // orderId => staff => % share (0-100)
//     mapping(bytes32 => TransferRequest) public pendingTransfers; // orderId => transfer request
//     mapping(address => bytes32[]) public staffActiveOrders; // staff => danh sách order đang xử lý
//     mapping(bytes32 => bool) public orderAcknowledged; // orderId => đã được acknowledge chưa

//     // Arrays
//     bytes32[] public allPaymentIds;
//     Payment[] public paymentHistory;
//     mapping(bytes32 => CustomerProfile) public customerProfiles;
//     mapping(uint => GroupFeature ) public mTimeToGroupFeature;
//     Order[] public allOrders;
//     mapping(uint => bytes32[]) public mTableToOrderIds;
//     mapping(uint => bytes32 ) public mTableToIdPayment;
    
//     INoti public noti;
//     mapping(string => mapping(bytes32 => uint)) mDishReviewIndex; 
//     IRestaurantReporting public Report;
//     mapping(uint256 => Review[]) private reviewsByDate;
//     mapping(uint =>mapping(uint => uint)) public mTableToCoursePrice;
//     mapping(bytes32 => Order) public mOrderIdToOrder;
//     address public iqrAgentSC;
//     address public agent;
//     address public revenueSC;
//     IPoint public POINTS;
//     mapping(bytes32 => uint256) public paymentPointsUsed;
//     mapping(uint256 => Review[]) private reviewsByMonth;
//     mapping(address => uint) public numberOfVisit;

//     // NEW: Struct cho transfer request
//     struct TransferRequest {
//         bytes32 orderId;
//         address fromStaff;
//         address toStaff;
//         uint timestamp;
//         TransferStatus status;
//         string reason;
//     }

//     enum TransferStatus {
//         NONE,
//         PENDING,
//         ACCEPTED,
//         DECLINED
//     }

//     // Events
//     event OrderMade(uint indexed table, bytes32 indexed orderId, uint courseCount);
//     event PaymentMade(uint indexed table, bytes32 indexed paymentId, uint total);
//     event PaymentConfirmed(bytes32 indexed paymentId, address staff);
//     event PaymentWithPoints(bytes32 indexed paymentId, address indexed customer, uint256 pointsUsed, uint256 pointsValue, uint256 remainingCash);
//     event OrderConfirmed(uint table, bytes32 orderId);
//     event CallStaff(uint table, uint amount);
//     event BatchCourseStatusUpdated(uint table, bytes32 _orderId, COURSE_STATUS newStatus);
//     event CourseStatusUpdated(uint table, bytes32 _orderId, uint _courseId, COURSE_STATUS newStatus);

//     // NEW: Events cho staff management
//     event OrderAcknowledged(bytes32 indexed orderId, address indexed staff, uint timestamp);
//     event OrderTransferRequested(bytes32 indexed orderId, address indexed fromStaff, address indexed toStaff, string reason);
//     event OrderTransferAccepted(bytes32 indexed orderId, address indexed fromStaff, address indexed toStaff);
//     event OrderTransferDeclined(bytes32 indexed orderId, address indexed fromStaff, address indexed toStaff, string reason);
//     event OrderNotificationSent(bytes32 indexed orderId, uint table, address[] recipients);
//     event OrderNotificationDismissed(bytes32 indexed orderId, address[] dismissedFor);

//     uint256[30] private __gap;

//     constructor() {
//         _disableInitializers();
//     }

//     function initialize() public initializer {
//         __ReentrancyGuard_init();
//         __Ownable_init(msg.sender);
//         __Pausable_init();
//         __UUPSUpgradeable_init();
//         taxPercent = 10;
//     }    

//     function _authorizeUpgrade(address newImplementation) internal override {}

//     modifier onlyStaff() {
//         require(MANAGEMENT.isStaff(msg.sender), "Not staff");
//         _;
//     }

//     // Configuration functions
//     function setConfig(
//         address _management,
//         address _merchant,
//         address _cardVisa,
//         uint8 _taxPercent,
//         address _noti,
//         address _report
//     ) external onlyOwner {
//         if (_management != address(0)) MANAGEMENT = IManagement(_management);
//         if (_merchant != address(0)) merchant = _merchant;
//         if (_cardVisa != address(0)) ICARD_VISA = ICardTokenManager(_cardVisa);
//         if (_taxPercent <= 100) taxPercent = _taxPercent;
//         if (_noti != address(0)) noti = INoti(_noti);
//         if (_report != address(0)) Report = IRestaurantReporting(_report);
//     }

//     function setPointSC(address _pointSC) external {
//         POINTS = IPoint(_pointSC);
//     }

//     function setIQRAgent(address _iqrAgentSC, address _agent, address revenueManager) external onlyOwner {
//         iqrAgentSC = _iqrAgentSC;
//         revenueSC = revenueManager;
//         agent = _agent;
//     }

//     struct GroupFeature {
//         uint time;
//         bool isDineIn;
//         uint8 groupSize;
//         bytes32[] customerIDs;
//     }

//     function setFeatureCustomers(
//         bool isDineIn,
//         uint8 groupSize,
//         bytes32[] memory customerIDs,
//         uint8[] memory genders,
//         uint8[] memory age,
//         uint time
//     ) external {
//         GroupFeature storage groups = mTimeToGroupFeature[time];
//         groups.isDineIn = isDineIn;
//         groups.groupSize = groupSize;
//         groups.customerIDs = customerIDs;
//         for(uint i; i < customerIDs.length; i++) {
//             CustomerProfile storage profile = customerProfiles[customerIDs[i]];
//             profile.gender = genders[i];
//             profile.ageGroup = age[i];
//             if (profile.firstVisit == 0) {
//                 profile.firstVisit = block.timestamp;
//             }
//             profile.visitCount++;
//         }
//     }

//     function ConfirmOrder(bytes32 orderId, ORDER_STATUS _status) external onlyStaff {
//         require(_status != ORDER_STATUS.UNCONFIRMED, "can not turn back status");
//         SimpleCourse[] memory courses = mOrderIdToCourses[orderId];
//         for (uint i = 0; i < courses.length; i++) {
//             if(_status == ORDER_STATUS.CONFIRMED) {
//                 require(courses[i].status == COURSE_STATUS.PREPARING || courses[i].status == COURSE_STATUS.CANCELED,
//                 "can not confirm order status CONFIRMED if course status is not preparing or cancelled status");
//             }
//             if(_status == ORDER_STATUS.FINISHED) {
//                 require(courses[i].status == COURSE_STATUS.SERVED || courses[i].status == COURSE_STATUS.CANCELED,
//                 "can not confirm order status FINISHED if course status is not SERVED or cancelled status");
//             }
//         }
//         bool found = false;
//         uint table;

//         for (uint i = 0; i < allOrders.length; i++) {
//             if (allOrders[i].id == orderId) {
//                 if(_status == ORDER_STATUS.CONFIRMED) {
//                     require(allOrders[i].status == ORDER_STATUS.UNCONFIRMED, "Order already confirmed or invalid");
//                 }
//                 if(_status == ORDER_STATUS.FINISHED) {
//                     require(allOrders[i].status == ORDER_STATUS.CONFIRMED, "Order already finished or invalid");
//                 }
//                 allOrders[i].status = _status;
//                 mOrderIdToOrder[orderId].status = _status;
//                 table = allOrders[i].table;
//                 found = true;
//                 break;
//             }
//         }
//         require(found, "Order not found");

//         Order[] storage tOrders = tableOrders[table];
//         for (uint j = 0; j < tOrders.length; j++) {
//             if (tOrders[j].id == orderId) {
//                 tOrders[j].status = _status;
//                 break;
//             }
//         }
//         acknowledgeOrder(orderId);
//         emit OrderConfirmed(table, orderId);
//     }

//     // NEW: Acknowledge order - nhân viên nhận đơn
//     function acknowledgeOrder(bytes32 orderId)  internal returns (bool) {
//         require(!orderAcknowledged[orderId], "Order already acknowledged");
//         require(mOrderIdToOrder[orderId].id != bytes32(0), "Order not found");
        
//         // Gán nhân viên chính cho đơn hàng
//         orderPrimaryStaff[orderId] = msg.sender;
//         orderAcknowledged[orderId] = true;
        
//         // Thêm vào lịch sử và set 100% share
//         orderStaffHistory[orderId].push(msg.sender);
//         orderStaffShare[orderId][msg.sender] = 100;
        
//         // Thêm vào danh sách order đang xử lý của staff
//         staffActiveOrders[msg.sender].push(orderId);
        
//         // Gửi thông báo dismiss cho tất cả staff khác
//         address[] memory allStaff = MANAGEMENT.GetActiveStaffAddressesByDate(block.timestamp);
//         _dismissOrderNotification(orderId, allStaff);
        
//         emit OrderAcknowledged(orderId, msg.sender, block.timestamp);
//         return true;
//     }

//     // NEW: Request transfer order
//     function requestTransferOrder(
//         bytes32 orderId,
//         address toStaff,
//         string memory reason
//     ) external onlyStaff returns (bool) {
//         require(orderPrimaryStaff[orderId] == msg.sender, "Only primary staff can transfer");
//         require(MANAGEMENT.isStaff(toStaff), "Recipient is not staff");
//         require(toStaff != msg.sender, "Cannot transfer to yourself");
//         require(pendingTransfers[orderId].status != TransferStatus.PENDING, "Transfer already pending");
        
//         // Tạo transfer request
//         pendingTransfers[orderId] = TransferRequest({
//             orderId: orderId,
//             fromStaff: msg.sender,
//             toStaff: toStaff,
//             timestamp: block.timestamp,
//             status: TransferStatus.PENDING,
//             reason: reason
//         });
        
//         // Gửi thông báo cho staff nhận
//         if (address(noti) != address(0)) {
//             Order memory order = mOrderIdToOrder[orderId];
//             NotiParams memory param = NotiParams({
//                 title: "Transfer Request",
//                 body: string(abi.encodePacked(
//                     "Table ", 
//                     order.table.toString(), 
//                     " - Reason: ", 
//                     reason
//                 ))
//             });
//             noti.AddNoti(param, toStaff);
//         }
        
//         emit OrderTransferRequested(orderId, msg.sender, toStaff, reason);
//         return true;
//     }

//     // NEW: Accept transfer
//     function acceptTransfer(bytes32 orderId) external onlyStaff returns (bool) {
//         TransferRequest storage transfer = pendingTransfers[orderId];
//         require(transfer.status == TransferStatus.PENDING, "No pending transfer");
//         require(transfer.toStaff == msg.sender, "Not the transfer recipient");
        
//         address fromStaff = transfer.fromStaff;
        
//         // Cập nhật staff chính
//         orderPrimaryStaff[orderId] = msg.sender;
        
//         // Thêm vào lịch sử
//         orderStaffHistory[orderId].push(msg.sender);
        
//         // Chia share 50-50 giữa 2 nhân viên
//         orderStaffShare[orderId][fromStaff] = 50;
//         orderStaffShare[orderId][msg.sender] = 50;
        
//         // Cập nhật danh sách active orders
//         _removeFromStaffActiveOrders(fromStaff, orderId);
//         staffActiveOrders[msg.sender].push(orderId);
        
//         // Cập nhật trạng thái transfer
//         transfer.status = TransferStatus.ACCEPTED;
        
//         // Gửi thông báo cho staff gốc
//         if (address(noti) != address(0)) {
//             Order memory order = mOrderIdToOrder[orderId];
//             NotiParams memory param = NotiParams({
//                 title: "Transfer Accepted",
//                 body: string(abi.encodePacked("Table ", order.table.toString()))
//             });
//             noti.AddNoti(param, fromStaff);
//         }
        
//         emit OrderTransferAccepted(orderId, fromStaff, msg.sender);
//         return true;
//     }

//     // NEW: Decline transfer
//     function declineTransfer(bytes32 orderId, string memory reason) external onlyStaff returns (bool) {
//         TransferRequest storage transfer = pendingTransfers[orderId];
//         require(transfer.status == TransferStatus.PENDING, "No pending transfer");
//         require(transfer.toStaff == msg.sender, "Not the transfer recipient");
        
//         address fromStaff = transfer.fromStaff;
//         transfer.status = TransferStatus.DECLINED;
        
//         // Gửi thông báo cho staff gốc
//         if (address(noti) != address(0)) {
//             Order memory order = mOrderIdToOrder[orderId];
//             NotiParams memory param = NotiParams({
//                 title: "Transfer Declined",
//                 body: string(abi.encodePacked(
//                     "Table ", 
//                     order.table.toString(),
//                     " - Reason: ",
//                     reason
//                 ))
//             });
//             noti.AddNoti(param, fromStaff);
//         }
        
//         emit OrderTransferDeclined(orderId, fromStaff, msg.sender, reason);
//         return true;
//     }

//     // Helper function để remove order khỏi staff active list
//     function _removeFromStaffActiveOrders(address staff, bytes32 orderId) internal {
//         bytes32[] storage orders = staffActiveOrders[staff];
//         for (uint i = 0; i < orders.length; i++) {
//             if (orders[i] == orderId) {
//                 orders[i] = orders[orders.length - 1];
//                 orders.pop();
//                 break;
//             }
//         }
//     }

//     // Helper function để dismiss notification cho staff khác
//     function _dismissOrderNotification(bytes32 orderId, address[] memory allStaff) internal {
//         address acknowledgedStaff = orderPrimaryStaff[orderId];
//         address[] memory dismissList = new address[](allStaff.length - 1);
//         uint count = 0;
        
//         for (uint i = 0; i < allStaff.length; i++) {
//             if (allStaff[i] != acknowledgedStaff) {
//                 dismissList[count] = allStaff[i];
//                 count++;
//             }
//         }
        
//         emit OrderNotificationDismissed(orderId, dismissList);
//     }

//     // Main order function - với notification cho tất cả staff
//     function makeOrder(
//         uint table,
//         string[] memory dishCodes,
//         uint8[] memory quantities,
//         string[] memory notes,
//         bytes32[] memory variantIDs,
//         SelectedOption[][] memory dishSelectedOptions 
//     ) external returns (bytes32 orderId) {
//         require(dishCodes.length == quantities.length, "Array length mismatch");
//         require(dishCodes.length == dishSelectedOptions.length, "dishOptionIds length mismatch");

//         orderId = keccak256(abi.encodePacked(table, block.timestamp, dishCodes.length));
        
//         Order memory order = Order({
//             id: orderId,
//             table: table,
//             createdAt: block.timestamp,
//             status: ORDER_STATUS.UNCONFIRMED
//         });
        
//         mTableToOrderIds[table].push(order.id);
//         mOrderIdToOrder[orderId] = order;
//         tableOrders[table].push(order);
        
//         uint totalPrice = _processCourses(table, orderId, dishCodes, quantities, notes, variantIDs, dishSelectedOptions);
//         _createOrUpdatePayment(table, order.id, totalPrice);
//         allOrders.push(order);
//         mTableToIdPayment[table] = mTableToPayment[table].id;

//         // NEW: Gửi thông báo cho TẤT CẢ staff
//         address[] memory allStaff = MANAGEMENT.GetActiveStaffAddressesByDate(block.timestamp);
//         if (address(noti) != address(0) && allStaff.length > 0) {
//             NotiParams memory param = NotiParams({
//                 title: "New Order",
//                 body: string(abi.encodePacked(
//                     "Table ", 
//                     table.toString(),
//                     " - ",
//                     dishCodes.length.toString(),
//                     " items"
//                 ))
//             });
            
//             for (uint i = 0; i < allStaff.length; i++) {
//                 noti.AddNoti(param, allStaff[i]);
//             }
            
//             emit OrderNotificationSent(orderId, table, allStaff);
//         }

//         emit OrderMade(table, orderId, dishCodes.length);
//         return orderId;
//     }

//     function _processCourses(
//         uint table,
//         bytes32 orderId,
//         string[] memory dishCodes,
//         uint8[] memory quantities,
//         string[] memory notes,
//         bytes32[] memory variantIDs,
//         SelectedOption[][] memory dishSelectedOptions
//     ) internal returns (uint totalPrice) {
//         uint courseIdStart = mTableToCourses[table].length + 1;
        
//         for (uint i = 0; i < dishCodes.length; i++) {
//             totalPrice += _addCourse(
//                 table, 
//                 orderId, 
//                 courseIdStart + i, 
//                 dishCodes[i], 
//                 quantities[i], 
//                 notes[i],
//                 variantIDs[i],
//                 dishSelectedOptions[i] 
//             );
//         }
//     }

//     function _addCourse(
//         uint table,
//         bytes32 orderId,
//         uint courseId,
//         string memory dishCode,
//         uint8 quantity,
//         string memory note,
//         bytes32 variantID,
//         SelectedOption[] memory selectedOptions
//     ) internal returns (uint coursePrice) {
//         require(quantity > 0, "quantity can be zero");
//         (string memory dishName, bool available, bool active, string memory imgUrl) = MANAGEMENT.GetDishBasic(dishCode);
//         require(available && active, "Dish unavailable");
//         Variant memory orderVariant = MANAGEMENT.getVariant(dishCode, variantID);
//         require(orderVariant.variantID != bytes32(0), "Variant not found");

//         (uint optionsPrice, OptionSelected[] memory optionsSelected) = MANAGEMENT.CalculateAndValidateOptions(dishCode, selectedOptions);
       
//         uint dishPrice = orderVariant.dishPrice;
//         SimpleCourse memory course = SimpleCourse({
//             id: courseId,
//             dishCode: dishCode,
//             dishName: dishName,
//             dishPrice: dishPrice + optionsPrice,
//             quantity: quantity,
//             status: COURSE_STATUS.ORDERED,
//             imgUrl: imgUrl,
//             note: note,
//             optionsSelected: optionsSelected
//         });
        
//         mOrderIdToCourses[orderId].push(course);
//         mTableToCourses[table].push(course);
//         mTableToIdToCourse[table][course.id] = course;
//         coursePrice = course.dishPrice * quantity;
//         mTableToCoursePrice[table][course.id] = coursePrice;
//     }

//     function _createOrUpdatePayment(
//         uint table,
//         bytes32 orderId,
//         uint totalPrice
//     ) internal {
//         Payment storage payment = mTableToPayment[table];
//         uint taxAmount = (totalPrice * taxPercent) / 100;

//         if (payment.id == bytes32(0)) {
//             bytes32 paymentId = keccak256(abi.encodePacked(table, block.timestamp));
//             payment.id = paymentId;
//             payment.tableNum = table;
//             payment.foodCharge = totalPrice;
//             payment.tax = taxAmount;
//             payment.total = totalPrice + taxAmount;
//             payment.status = PAYMENT_STATUS.CREATED;  
//             payment.orderIds = mTableToOrderIds[table];
//             payment.createdAt = block.timestamp;
//             mTableToPayment[table] = payment;        
//             mIdToPayment[paymentId] = payment;
//             allPaymentIds.push(paymentId);
//         } else {
//             payment.orderIds.push(orderId);
//             payment.foodCharge += totalPrice;
//             payment.tax += taxAmount;
//             payment.total = payment.foodCharge + payment.tax + payment.tip - payment.discountAmount;
//             mIdToPayment[payment.id] = payment;
//         }
        
//         for(uint i; i < mOrderIdToCourses[orderId].length; i++) {
//             paymentCourses[payment.id].push(mOrderIdToCourses[orderId][i]);
//         }
//     }

//     function UpdateOrder(
//         uint _numTable,
//         bytes32 _orderId,
//         uint[] memory _courseIds,
//         uint[] memory _quantities
//     ) external returns(bool) {
//         require(_courseIds.length == _quantities.length, "number of course id should be equal to number of quantity");
//         Payment storage payment = mTableToPayment[_numTable];         
//         SimpleCourse[] storage courseArr = mOrderIdToCourses[_orderId];
//         SimpleCourse[] storage courses = mTableToCourses[_numTable];
        
//         for (uint i; i < _courseIds.length; i++) {
//             for (uint j = 0; j < courseArr.length; j++) {
//                 if (courseArr[j].id == _courseIds[i]) {
//                     if(courseArr[j].quantity == _quantities[i]) {
//                         break;
//                     }
//                     if(courseArr[j].quantity > _quantities[i]) {
//                         uint diffPrice = (courseArr[j].quantity - _quantities[i]) * courseArr[j].dishPrice;
//                         payment.foodCharge -= diffPrice;
//                         payment.tax -= diffPrice * taxPercent / 100;
//                         payment.total -= diffPrice + diffPrice * taxPercent / 100;
//                     }
//                     if(courseArr[j].quantity < _quantities[i]) {
//                         uint diffPrice = (_quantities[i] - courseArr[j].quantity) * courseArr[j].dishPrice;
//                         payment.foodCharge += diffPrice;
//                         payment.tax += diffPrice * taxPercent / 100;
//                         payment.total += diffPrice + diffPrice * taxPercent / 100;
//                     }                 
//                     courseArr[j].quantity = _quantities[i];
//                     break; 
//                 }
//             }
//             for (uint j = 0; j < courses.length; j++) {
//                 if (courses[j].id == _courseIds[i]) {
//                     courses[j].quantity = _quantities[i];
//                     break; 
//                 }
//             }
//         }
        
//         mIdToPayment[payment.id] = payment;
//         for(uint i; i < _courseIds.length; i++) {
//             SimpleCourse storage course = mTableToIdToCourse[_numTable][_courseIds[i]];
//             require(course.status == COURSE_STATUS.ORDERED, "course can not change anymore");
//             course.quantity = _quantities[i];           
//         }
//         return true;       
//     }

//     function _applyDiscount(
//         Payment storage payment,
//         string memory discountCode,
//         bytes32 customerGroup
//     ) internal returns (uint discountAmount) {
//         if (bytes(discountCode).length == 0) return 0;
        
//         (
//             uint discountPercent,
//             bool active,
//             uint amountUsed,
//             uint amountMax,
//             uint from,
//             uint to,
//             DiscountType discountType,
//             bytes32[] memory targetGroupIds
//         ) = MANAGEMENT.GetDiscountBasic(discountCode);
        
//         require(active, "Discount inactive");
//         require(amountUsed < amountMax, "Discount limit reached");
//         require(block.timestamp >= from && block.timestamp <= to, "Discount expired");
        
//         if (discountType == DiscountType.AUTO_GROUP) {
//             require(customerGroup != bytes32(0), "Customer not in any group");
//             bool inTargetGroup = false;
//             for (uint i = 0; i < targetGroupIds.length; i++) {
//                 if (targetGroupIds[i] == customerGroup) {
//                     inTargetGroup = true;
//                     break;
//                 }
//             }
//             require(inTargetGroup, "Not eligible for this group discount");
//         }
        
//         MANAGEMENT.UpdateDiscountCodeUsed(discountCode);
//         return (payment.foodCharge * discountPercent) / 100;
//     }

//     // Staff functions - cập nhật để ghi nhận staff thông qua orderPrimaryStaff
//     function confirmPayment(
//         uint table,
//         bytes32 paymentId,
//         string memory reason
//     ) external onlyStaff returns (bool) {
//         Payment storage payment = mIdToPayment[paymentId];
//         require(payment.status == PAYMENT_STATUS.PAID, "Payment not paid");
        
//         payment.status = PAYMENT_STATUS.CONFIRMED_BY_STAFF;        
//         payment.staffConfirm = msg.sender;
//         payment.reasonConfirm = reason;
        
//         // NEW: Remove orders khỏi staff active list
//         bytes32[] memory orderIds = payment.orderIds;
//         for (uint i = 0; i < orderIds.length; i++) {
//             address primaryStaff = orderPrimaryStaff[orderIds[i]];
//             if (primaryStaff != address(0)) {
//                 _removeFromStaffActiveOrders(primaryStaff, orderIds[i]);
//             }
//         }
        
//         _clearTable(table);
//         Report.UpdateDailyStats(block.timestamp/86400, payment.foodCharge, 1);
//         if(iqrAgentSC != address(0)) {
//             createOrderDataForAgentManagement(paymentId, payment.foodCharge);
//         }
//         emit PaymentConfirmed(paymentId, msg.sender);
//         return true;
//     }

//     function callStaff(uint table, uint amount) external {
//         address[] memory staffsPayment = MANAGEMENT.GetStaffRolePayment();
//         emit CallStaff(table, amount);
//     }

//     function BatchUpdateCourseStatus(
//         uint table,
//         bytes32 _orderId,
//         COURSE_STATUS newStatus
//     ) external onlyStaff {
//         SimpleCourse[] memory courses = mOrderIdToCourses[_orderId];
//         for(uint i; i < courses.length; i++) {
//             if(courses[i].status == COURSE_STATUS.CANCELED || courses[i].status == COURSE_STATUS.SERVED) {
//                 continue;
//             }
//             _updateCourseStatus(table, _orderId, courses[i].id, newStatus);
//         }
//         emit BatchCourseStatusUpdated(table, _orderId, newStatus);
//     }

//     function updateCourseStatus(
//         uint table,
//         bytes32 _orderId,
//         uint _courseId,
//         COURSE_STATUS newStatus
//     ) external onlyStaff {
//         _updateCourseStatus(table, _orderId, _courseId, newStatus);
//     }

//     function _updateCourseStatus(
//         uint table,
//         bytes32 _orderId,
//         uint _courseId,
//         COURSE_STATUS newStatus
//     ) internal {
//         require(newStatus != COURSE_STATUS.ORDERED,
//                 "course status of ORDERED autonomically set when make a new order"
//         );
//         SimpleCourse storage course = mTableToIdToCourse[table][_courseId];
//         if (
//             (newStatus == COURSE_STATUS.PREPARING && course.status != COURSE_STATUS.ORDERED) ||
//             (newStatus == COURSE_STATUS.SERVED && course.status != COURSE_STATUS.PREPARING)
//         ) {
//             revert("Invalid Status");
//         }
        
//         course.status = newStatus;
//         SimpleCourse[] storage coursesOrder = mOrderIdToCourses[_orderId];
//         for(uint i; i < coursesOrder.length; i++) {
//             if (_courseId == coursesOrder[i].id) {
//                 coursesOrder[i].status = newStatus;
//                 break;
//             }
//         }
//         SimpleCourse[] storage coursesTable = mTableToCourses[table];
//         for(uint i; i < coursesTable.length; i++) {
//             if (_courseId == coursesTable[i].id) {
//                 coursesTable[i].status = newStatus;
//                 break;
//             }
//         }
//         Payment memory payment = mTableToPayment[table];
//         SimpleCourse[] storage coursesPayment = paymentCourses[payment.id];
//         for(uint i; i < coursesPayment.length; i++) {
//             if (_courseId == coursesPayment[i].id) {
//                 coursesPayment[i].status = newStatus;
//                 break;
//             }        
//         }
//         emit CourseStatusUpdated(table, _orderId, _courseId, newStatus);
//     }

//     function _clearTable(uint table) internal {
//         delete mTableToCourses[table];
//         delete tableOrders[table];
//         delete mTableToOrderIds[table];
//         delete mTableToPayment[table];
//     }

//     function executeOrder(
//         uint table,
//         string memory discountCode,
//         uint tip,
//         uint256 paymentAmount,
//         string memory txID,
//         bool usePoint
//     ) external whenNotPaused nonReentrant returns (bool) {
//         if (bytes(txID).length != 0) {
//             require(!usedTxIds[txID], "Transaction ID already used");
//             TransactionStatus memory transaction = ICARD_VISA.getTx(txID);
//             require(transaction.status == TxStatus.SUCCESS, "Transaction not successful");
//             PoolInfo memory poolInfo = ICARD_VISA.getPoolInfo(txID);
//             require(poolInfo.ownerPool == merchant, "Merchant address mismatch");
//             require(poolInfo.parentValue == paymentAmount, "amount not matched");
//         }
        
//         Payment storage payment = mTableToPayment[table];
//         require(payment.status == PAYMENT_STATUS.CREATED, "Invalid payment status");
        
//         bytes32 customerGroup = bytes32(0);
//         if (address(POINTS) != address(0)) {
//             customerGroup = POINTS.getMemberToGroup(msg.sender);
//         }
//         uint discountAmount = _applyDiscount(payment, discountCode, customerGroup);
        
//         payment.tip = tip;
//         payment.discountAmount = discountAmount;
//         payment.total = payment.foodCharge + payment.tax + payment.tip - payment.discountAmount;
        
//         require(paymentAmount >= payment.total, "Insufficient payment amount");
        
//         uint256 pointsUsed = 0;
//         uint256 pointsValue = 0;
//         uint256 remainingAmount = payment.total;
        
//         if (usePoint && address(POINTS) != address(0)) {
//             (pointsUsed, pointsValue, remainingAmount) = _processPointPayment(msg.sender, payment.total);
//             paymentPointsUsed[payment.id] = pointsUsed;
//             emit PaymentWithPoints(payment.id, msg.sender, pointsUsed, pointsValue, remainingAmount);
//         }
        
//         if (remainingAmount > 0) {
//             if (bytes(txID).length != 0) {
//                 require(!usedTxIds[txID], "Transaction ID already used");
//                 TransactionStatus memory transaction = ICARD_VISA.getTx(txID);
//                 require(transaction.status == TxStatus.SUCCESS, "Transaction not successful");
//                 PoolInfo memory poolInfo = ICARD_VISA.getPoolInfo(txID);
//                 require(poolInfo.ownerPool == merchant, "Merchant address mismatch");
//                 require(poolInfo.parentValue >= remainingAmount, "Insufficient payment amount");
//                 usedTxIds[txID] = true;
//                 payment.method = usePoint ? "VISA + POINTS" : "VISA";
//             } else {
//                 require(paymentAmount >= remainingAmount, "Insufficient payment amount");
//                 payment.method = usePoint ? "CASH + POINTS" : "CASH";
//             }
//         } else {
//             payment.method = "POINTS";
//         }
        
//         payment.status = PAYMENT_STATUS.PAID;
//         payment.createdAt = block.timestamp;
        
//         Payment storage meta = mTableToPayment[table];
//         meta.discountCode = discountCode;
        
//         mIdToPayment[payment.id] = payment;
//         mIdToPayment[payment.id] = meta;
//         usedTxIds[txID] = true;
//         paymentHistory.push(payment);
        
//         if(address(POINTS) != address(0)) {
//             if(POINTS.isMemberPointSystem(msg.sender)) {
//                 POINTS.updateLastBuyActivityAt(msg.sender);
//             }
//         }
//         emit PaymentMade(table, payment.id, payment.total);
//         return true;
//     }

//     function _processPointPayment(
//         address customer,
//         uint256 totalAmount
//     ) internal returns (
//         uint256 pointsUsed,
//         uint256 pointsValue,
//         uint256 remainingAmount
//     ) {
//         (
//             ,
//             uint256 totalPoints,
//             ,
//             ,
//             ,
//             ,
//             bool isActive,
//             bool isLocked,
//             ,
//             ,
//         ) = POINTS.getMember(customer);
        
//         require(isActive, "Member not active");
//         require(!isLocked, "Member account is locked");
//         require(totalPoints > 0, "No points available");
        
//         (uint256 exchangeRate, uint256 maxPercentPerInvoice) = POINTS.getPaymentConfig();
//         uint256 maxPayableAmount = (totalAmount * maxPercentPerInvoice) / 100;
//         uint256 totalPointsValue = totalPoints * exchangeRate;
        
//         if (totalPointsValue >= maxPayableAmount) {
//             pointsValue = maxPayableAmount;
//             pointsUsed = pointsValue / exchangeRate;
//         } else {
//             pointsValue = totalPointsValue;
//             pointsUsed = totalPoints;
//         }
        
//         remainingAmount = totalAmount > pointsValue ? totalAmount - pointsValue : 0;
//         POINTS.usePointsForPayment(customer, pointsUsed, totalAmount);
//         return (pointsUsed, pointsValue, remainingAmount);
//     }

//     function previewPointPayment(
//         uint table,
//         address customer,
//         string memory discountCode
//     ) external view returns (
//         uint256 totalAmount,
//         uint256 maxPointsCanUse,
//         uint256 maxValueCanPay,
//         uint256 remainingAmount,
//         bool canPayFully
//     ) {
//         require((address(POINTS) != address(0)), "Points contract not set yet");
//         Payment memory payment = mTableToPayment[table];
        
//         bytes32 customerGroup = bytes32(0);
//         if (address(POINTS) != address(0)) {
//             customerGroup = POINTS.getMemberToGroup(customer);
//         }
        
//         uint discountAmount = 0;
//         if (bytes(discountCode).length > 0) {
//             (
//                 uint discountPercent,
//                 bool active,
//                 uint amountUsed,
//                 uint amountMax,
//                 uint from,
//                 uint to,
//                 ,
//             ) = MANAGEMENT.GetDiscountBasic(discountCode);
            
//             if (active && amountUsed < amountMax && block.timestamp >= from && block.timestamp <= to) {
//                 discountAmount = (payment.foodCharge * discountPercent) / 100;
//             }
//         }
        
//         totalAmount = payment.foodCharge + payment.tax + payment.tip - discountAmount;
        
//         (
//             ,
//             uint256 totalPoints,
//             ,
//             ,
//             ,
//             ,
//             bool isActive,
//             bool isLocked,
//             ,
//             ,
//         ) = POINTS.getMember(customer);
        
//         if (!isActive || isLocked || totalPoints == 0) {
//             return (totalAmount, 0, 0, totalAmount, false);
//         }
        
//         (uint256 exchangeRate, uint256 maxPercentPerInvoice) = POINTS.getPaymentConfig();
//         uint256 maxPayableAmount = (totalAmount * maxPercentPerInvoice) / 100;
//         uint256 totalPointsValue = totalPoints * exchangeRate;
        
//         if (totalPointsValue >= maxPayableAmount) {
//             maxPointsCanUse = maxPayableAmount / exchangeRate;
//             maxValueCanPay = maxPayableAmount;
//             remainingAmount = totalAmount - maxPayableAmount;
//             canPayFully = (maxPayableAmount >= totalAmount);
//         } else {
//             maxPointsCanUse = totalPoints;
//             maxValueCanPay = totalPointsValue;
//             remainingAmount = totalAmount - totalPointsValue;
//             canPayFully = (totalPointsValue >= totalAmount);
//         }
        
//         return (totalAmount, maxPointsCanUse, maxValueCanPay, remainingAmount, canPayFully);
//     }

//     function getPaymentPointsInfo(bytes32 paymentId) external view returns (
//         uint256 pointsUsed,
//         uint256 pointsValue,
//         string memory paymentMethod
//     ) {
//         pointsUsed = paymentPointsUsed[paymentId];
//         Payment memory payment = mIdToPayment[paymentId];
        
//         if (pointsUsed > 0 && address(POINTS) != address(0)) {
//             (uint256 exchangeRate,) = POINTS.getPaymentConfig();
//             pointsValue = pointsUsed * exchangeRate;
//         }
        
//         return (pointsUsed, pointsValue, payment.method);
//     }

//     function UpdateForReport(uint table) external {
//         for (uint i = 0; i < mTableToCourses[table].length; i++) {
//             SimpleCourse memory course = mTableToCourses[table][i];
//             if(course.quantity > 0) {
//                 MANAGEMENT.UpdateOrderNum(course.dishCode, course.quantity, block.timestamp);
//                 uint dishPrice = mTableToCoursePrice[table][course.id];
//                 Report.UpdateDishDailyData(course.dishCode, block.timestamp, dishPrice, 1);
//             }
//         }
//         uint256 date = _getDay(block.timestamp);
//         Report.UpdateDailyStatsCustomer(date, 1);
//         numberOfVisit[msg.sender] ++;
//         Report.UpdateNewCustomerData(date,numberOfVisit[msg.sender]);
//     }
    
//     function getPaymentCourses(bytes32 _paymentID) external view returns(SimpleCourse[] memory courses, Payment memory payment) {
//         return (paymentCourses[_paymentID], mIdToPayment[_paymentID]);
//     }

//     function makeReview(
//         bytes32 paymentId,
//         uint8 overalStar,
//         string[] memory dishCodes,
//         uint8[] memory dishStars,
//         string memory contribution,
//         string memory nameCustomer
//     ) external returns (bool) {
//         require(mIdToPayment[paymentId].id != bytes32(0), "Payment not found");
//         require(overalStar >= 1 && overalStar <= 5, "Invalid food rating");
//         require(dishCodes.length == dishStars.length, "number of dishCodes and stars not match");
//         bytes32 id = keccak256(abi.encodePacked(block.timestamp, paymentId, contribution));
        
//         if (dishCodes.length > 0) {
//             for (uint i = 0; i < dishCodes.length; i++) {
//                 DishReview memory dishReview = DishReview({
//                     nameCustomer: nameCustomer,
//                     dishCode: dishCodes[i],
//                     dishStar: dishStars[i],
//                     contribution: contribution,
//                     createdAt: block.timestamp,
//                     paymentId: paymentId,
//                     isShow: true,
//                     id: id
//                 });
//                 mDishCodeToReviews[dishCodes[i]].push(dishReview);
//                 mDishReviewIndex[dishCodes[i]][id] = mDishCodeToReviews[dishCodes[i]].length - 1;
//                 MANAGEMENT.updateAverageStarDish(dishStars[i], dishCodes[i]);
//             }
//         }

//         reviews[paymentId] = Review({
//             nameCustomer: nameCustomer,
//             overalStar: overalStar,
//             contribution: contribution,
//             createdAt: block.timestamp,
//             paymentId: paymentId
//         });
        
//         uint256 date = _getDay(block.timestamp);
//         uint256 month = _getMonth(block.timestamp);
//         reviewsByDate[date].push(reviews[paymentId]);
//         reviewsByMonth[month].push(reviews[paymentId]);
//         return true;
//     }

//     function _getDay(uint timestamp) internal pure returns (uint) {
//         return timestamp / 86400;
//     }
    
//     function _getMonth(uint timestamp) internal pure returns (uint) {
//         return timestamp / (86400 * 30);
//     }

// function getReviewsByMonth(
//     uint256 month,
//     uint256 page,
//     uint256 pageSize
// ) external view returns (Review[] memory, uint256 totalCount, uint256 totalPages, uint256 currentPage) {
//     require(pageSize > 0, "Page size must be greater than 0");
    
//     Review[] storage allReviews = reviewsByMonth[month];
//     totalCount = allReviews.length;
    
//     // Tính tổng số trang
//     totalPages = (totalCount + pageSize - 1) / pageSize;
    
//     // Nếu không có dữ liệu
//     if (totalCount == 0) {
//         return (new Review[](0), 0, 0, page);
//     }
    
//     // Nếu page vượt quá totalPages (page bắt đầu từ 0 nên so sánh với totalPages)
//     if (page >= totalPages) {
//         return (new Review[](0), totalCount, totalPages, page);
//     }
    
//     // Tính start và end index (page bắt đầu từ 0)
//     uint256 startIndex = page * pageSize;
//     if (startIndex >= totalCount) {
//         return (new Review[](0), totalCount, totalPages, page);
//     } 
//     uint256 endIndex = startIndex + pageSize;
    
//     if (endIndex > totalCount) {
//         endIndex = totalCount;
//     }
    
//     // Tạo mảng kết quả
//     uint256 remaining = endIndex - startIndex;
//     uint256 resultSize = remaining < pageSize ? remaining : pageSize;
//     Review[] memory result = new Review[](resultSize);
    
//     for (uint256 i = 0; i < resultSize; i++) {
//         uint256 reverseIndex = totalCount - 1 - startIndex - i;
//         result[i] = allReviews[reverseIndex];
//     }
    
//     return (result, totalCount, totalPages, page);
// }     
//    // Hàm lấy reviews theo date
//     function getReviewsByDate(                                                                  
//         uint256 date,
//         uint256 page,
//         uint256 pageSize
//     ) external view returns (Review[] memory,uint256 totalCount,uint256 totalPages,uint256 currentPage) {
//         require(pageSize > 0, "Page size must be greater than 0");
//         // require(page > 0, "Page must be greater than 0");
        
//         Review[] storage allReviews = reviewsByDate[date];
//         totalCount = allReviews.length;
//         // Tính tổng số trang
//         totalPages = (totalCount + pageSize - 1) / pageSize;
//         // Nếu không có dữ liệu
//         if (totalCount == 0) {
//             return (new Review[](0), 0, 0, page);
//         }
//         // Nếu page vượt quá totalPages
//         if (page > totalPages) {
            
//             return (new Review[](0), totalCount, totalPages, page);
//         }
        
//         // Tính start và end index
//         uint256 startIndex = page * pageSize;    
//         if (startIndex >= totalCount) {
//             return (new Review[](0), totalCount, totalPages, page);
//         }    
//         uint256 endIndex = startIndex + pageSize;
//         if (endIndex > totalCount) {
//             endIndex = totalCount;
//         }
//         // Tạo mảng kết quả
//          uint256 remaining = endIndex - startIndex;
//         uint256 resultSize = remaining < pageSize ? remaining : pageSize;
//         Review[] memory result = new Review[](resultSize);
        
//         for (uint256 i = 0; i < resultSize; i++) {
//             uint256 reverseIndex = totalCount - 1 - startIndex - i;
//             result[i] = allReviews[reverseIndex];
//         }
        
//         return (result, totalCount, totalPages, page);
//     }


//     function BatchUpdateHideReview(bytes32[] memory reviewIds, string memory dishCode) external {
//         require(reviewIds.length > 0, "reviewid array can be empty");  
//         for(uint i; i < reviewIds.length; i++) {
//             _hideReview(reviewIds[i], dishCode);
//         }
//     }

//     function _hideReview(bytes32 reviewId, string memory dishCode) internal {
//         uint index = mDishReviewIndex[dishCode][reviewId];
//         DishReview storage review = mDishCodeToReviews[dishCode][index];
//         review.isShow = false;
//     }

//     function getReviewByDish(string memory dishCodes) external view returns (DishReview[] memory) {
//         return mDishCodeToReviews[dishCodes];
//     }

//     // NEW: View functions cho staff management
//     function getOrderStaffInfo(bytes32 orderId) external view returns (
//         address primaryStaff,
//         address[] memory staffHistory,
//         uint8 primaryStaffShare
//     ) {
//         primaryStaff = orderPrimaryStaff[orderId];
//         staffHistory = orderStaffHistory[orderId];
//         primaryStaffShare = orderStaffShare[orderId][primaryStaff];
//         return (primaryStaff, staffHistory, primaryStaffShare);
//     }

//     function getStaffShareForOrder(bytes32 orderId, address staff) external view returns (uint8) {
//         return orderStaffShare[orderId][staff];
//     }

//     function getPendingTransfer(bytes32 orderId) external view returns (TransferRequest memory) {
//         return pendingTransfers[orderId];
//     }

//     function getStaffActiveOrders(address staff) external view returns (bytes32[] memory) {
//         return staffActiveOrders[staff];
//     }

//     function getStaffActiveOrdersCount(address staff) external view returns (uint) {
//         return staffActiveOrders[staff].length;
//     }

//     function isOrderAcknowledged(bytes32 orderId) external view returns (bool) {
//         return orderAcknowledged[orderId];
//     }

//     // Existing view functions
//     function getTableOrderCount(uint table) external view returns (uint) {
//         return tableOrders[table].length;
//     }

//     function GetOrders(uint _numTable) external view returns(Order[] memory) {
//         return tableOrders[_numTable];
//     }

//     function GetOrderById(bytes32 orderId) external view returns(Order memory) {
//         return mOrderIdToOrder[orderId];
//     }

//     function GetOrdersPaginationByStatus(
//         uint offset, 
//         uint limit,
//         ORDER_STATUS _status
//     ) external view returns(Order[] memory, uint totalCount) {
//         totalCount = 0;

//         for(uint i; i < allOrders.length; i++) {
//             if(allOrders[i].status == _status) {
//                 totalCount++;
//             }
//         }
//         if(offset >= totalCount) {
//             return (new Order[](0), totalCount);
//         }
//         uint remaining = totalCount - offset;
//         uint count = remaining < limit ? remaining : limit;
//         Order[] memory orders = new Order[](count);
//         uint foundCount = 0;
//         uint skipped = 0;
//         for (uint i = allOrders.length; i > 0 && foundCount < count; i--) {
//             uint index = i - 1;
//             if(allOrders[index].status == _status) {
//                 if(skipped < offset) {
//                     skipped++;
//                     continue;
//                 }
//                 orders[foundCount] = allOrders[index];
//                 foundCount++;
//             }
//         }
//         return (orders, totalCount);
//     }

//     function GetOrdersByStatus(
//         ORDER_STATUS _status
//     ) external view returns(Order[] memory) {
//         uint totalCount = 0;

//         for(uint i; i < allOrders.length; i++) {
//             if(allOrders[i].status == _status) {
//                 totalCount++;
//             }
//         }
//         Order[] memory orders = new Order[](totalCount);
//         uint foundCount = 0;
//         for (uint i = allOrders.length; i > 0 && foundCount < totalCount; i--) {
//             uint index = i - 1;
//             if(allOrders[index].status == _status) {
//                 orders[foundCount] = allOrders[index];
//                 foundCount++;
//             }
//         }
//         return (orders);
//     }

//     function getTableCourseCount(uint table) external view returns (uint) {
//         return mTableToCourses[table].length;
//     }

//     function getTableOrder(uint table, uint index) external view returns (Order memory) {
//         require(index < tableOrders[table].length, "Index out of bounds");
//         return tableOrders[table][index];
//     }

//     function getTableCourse(uint table, uint index) external view returns (SimpleCourse memory) {
//         require(index < mTableToCourses[table].length, "Index out of bounds");
//         return mTableToCourses[table][index];
//     }

//     function GetCoursesByTable(uint _numTable) external view returns(SimpleCourse[] memory) {
//         return mTableToCourses[_numTable];
//     }

//     function GetAllOrders() external view returns(Order[] memory) {
//         return allOrders;
//     }

//     function GetCoursesByOrderId(bytes32 _idOrder) external view returns(SimpleCourse[] memory) {
//         return mOrderIdToCourses[_idOrder];
//     }

//     function getPayment(bytes32 paymentId) public view returns (Payment memory) {
//         return mIdToPayment[paymentId];
//     }

//     function isValidAmount(bytes32 _paymentId, uint _amount) external view returns(bool) {
//         Payment memory payment = getPayment(_paymentId);
//         return (payment.foodCharge - payment.discountAmount) == _amount;
//     }

//     function getTablePayment(uint table) external view returns (Payment memory) {
//         Payment memory payment = mTableToPayment[table];
//         return payment;
//     }

//     function GetLastIdPaymentByTable(uint _numTable) external view returns(bytes32) {
//         return mTableToIdPayment[_numTable];
//     }

//     function getReview(bytes32 paymentId) external view returns (Review memory) {
//         return reviews[paymentId];
//     }

//     function getPaymentHistoryCount() external view returns (uint) {
//         return paymentHistory.length;
//     }

//     function getPaymentHistoryItem(uint index) external view returns (Payment memory) {
//         require(index < paymentHistory.length, "Index out of bounds");
//         return paymentHistory[index];
//     }

//     function getPaymentsWithStatus(uint offset, uint limit) external view returns (Payment[] memory payments, uint totalCount) {
//         uint paymentCount = paymentHistory.length;
//         totalCount = paymentCount;
        
//         if (paymentCount == 0 || offset >= paymentCount) {
//             return (new Payment[](0), totalCount);
//         }
        
//         uint remainingItems = paymentCount - offset;
//         if (limit > remainingItems) {
//             limit = remainingItems;
//         }
//         if (limit == 0) {
//             return (new Payment[](0), totalCount);
//         }
        
//         return (_getPaymentsNotPaid(offset, limit));
//     }

//     function _getPaymentsNotPaid(uint offset, uint limit) internal view returns (Payment[] memory payments, uint totalCount) {
//         uint paymentCount = paymentHistory.length;
//         Payment[] memory paymentsNotPaid = new Payment[](paymentCount);
//         uint count;
//         for(uint i; i < paymentCount; i++) {
//             if(paymentHistory[i].status == PAYMENT_STATUS.CREATED) {
//                 paymentsNotPaid[count] = paymentHistory[i];
//                 count++;
//             }
//         }
//         Payment[] memory result = new Payment[](limit);
//         for (uint i = 0; i < limit; i++) {
//             result[i] = paymentsNotPaid[offset + i];
//         }
//         return (result, paymentCount);
//     }

//     struct PaymentInfo {
//         Payment payment;
//         SimpleCourse[] courses;
//     }

//     function getPaymentsPagination(uint offset, uint limit) external view returns (PaymentInfo[] memory payments, uint totalCount) {
//         uint paymentCount = allPaymentIds.length;
//         totalCount = paymentCount;
        
//         if (paymentCount == 0 || offset >= paymentCount) {
//             return (new PaymentInfo[](0), totalCount);
//         }
        
//         uint remainingItems = paymentCount - offset;
//         if (limit > remainingItems) {
//             limit = remainingItems;
//         }
//         if (limit == 0) {
//             return (new PaymentInfo[](0), totalCount);
//         }
        
//         return (_getPayments(offset, limit));
//     }

//     function _getPayments(uint offset, uint limit) internal view returns (PaymentInfo[] memory payments, uint totalCount) {
//         uint paymentCount = allPaymentIds.length;
//         PaymentInfo[] memory result = new PaymentInfo[](limit);
//         for (uint i = 0; i < limit; i++) {
//             uint256 reverseIndex = paymentCount - 1 - offset - i;
//             result[i] = PaymentInfo({
//                 payment: mIdToPayment[allPaymentIds[reverseIndex]],
//                 courses: paymentCourses[allPaymentIds[reverseIndex]]
//             });
//         }
//         return (result, paymentCount);
//     }

//     function getTaxPercent() external view returns (uint8) {
//         return taxPercent;
//     }

//     function createOrderDataForAgentManagement(bytes32 paymentId, uint amount) internal {
//         require(iqrAgentSC != address(0) && revenueSC != address(0), "revenueSC or iqrAgentSC not set yet");
//         IIQRAgent(iqrAgentSC).createOrder(paymentId, amount);
//     }
    
// }