// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IManagement.sol";
import "./interfaces/INoti.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IReport.sol";
// import "forge-std/console.sol";

// import "./interfaces/IRestaurant.sol";
contract RestaurantOrder is 
    Initializable, 
    ReentrancyGuardUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    UUPSUpgradeable  
{
    using Strings for uint256;

    // State variables
    IManagement public MANAGEMENT;
    IERC20 public SCUsdt;
    ICardTokenManager public ICARD_VISA;
    
    address public MasterPool;
    address public merchant;
    uint8 public taxPercent; // Use uint8 instead of uint

    // Core mappings - simplified
    mapping(uint => Order[]) public tableOrders;
    mapping(uint => SimpleCourse[]) public mTableToCourses;
    mapping(uint => Payment) public mTableToPayment;
    // mapping(bytes32 => Payment) public mIdToPayment;
    mapping(bytes32 => Payment) public mIdToPayment;
    mapping(bytes32 => SimpleCourse[]) public paymentCourses;
    mapping(bytes32 => Review) public reviews;
    mapping(string => DishReview[]) public mDishCodeToReviews;
    mapping(address => mapping(string => uint)) public customerDishCounts;
    mapping(string => bool) public usedTxIds;
    mapping(bytes32 => SimpleCourse[]) public mOrderIdToCourses; //IdOrder => []SimpleCourse
    mapping(uint => mapping(uint => SimpleCourse)) public mTableToIdToCourse; //Table number => IdCourse => Course

    // Arrays
    bytes32[] public allPaymentIds;
    Payment[] public paymentHistory;
    mapping(bytes32 => CustomerProfile) public customerProfiles;
    mapping(uint => GroupFeature ) public mTimeToGroupFeature;
    Order[] public allOrders;
    mapping(uint => bytes32[]) public mTableToOrderIds;
    mapping(uint => bytes32 ) public mTableToIdPayment; // Table number => last IdPayment
    
    INoti public noti;
    mapping(string => mapping(bytes32 => uint)) mDishReviewIndex; 
    IRestaurantReporting public Report;
    mapping(uint256 => Review[]) private reviewsByDate; // date => Review[]
    mapping(uint =>mapping(uint => uint)) public mTableToCoursePrice; //table => courseId => coursePrice

    // Events
    event OrderMade(uint indexed table, bytes32 indexed orderId, uint courseCount);
    event PaymentMade(uint indexed table, bytes32 indexed paymentId, uint total);
    event PaymentConfirmed(bytes32 indexed paymentId, address staff);

    uint256[41] private __gap;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        taxPercent = 10; // Default 10%
    }    

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyStaff() {
        require(MANAGEMENT.isStaff(msg.sender), "Not staff");
        _;
    }

    // Configuration functions
    function setConfig(
        address _management,
        address _usdt, 
        address _masterPool,
        address _merchant,
        address _cardVisa,
        uint8 _taxPercent,
        address _noti,
        address _report
    ) external onlyOwner {
        if (_management != address(0)) MANAGEMENT = IManagement(_management);
        if (_usdt != address(0)) SCUsdt = IERC20(_usdt);
        if (_masterPool != address(0)) MasterPool = _masterPool;
        if (_merchant != address(0)) merchant = _merchant;
        if (_cardVisa != address(0)) ICARD_VISA = ICardTokenManager(_cardVisa);
        if (_taxPercent <= 100) taxPercent = _taxPercent;
        if (_noti != address(0)) noti = INoti(_noti);
        if (_report != address(0)) Report = IRestaurantReporting(_report);
    }
    function setReport(address _report) external onlyOwner{
        Report = IRestaurantReporting(_report);
    }
    struct GroupFeature{
        uint time;
        bool isDineIn;
        uint8 groupSize;
        bytes32[] customerIDs;
    }
    function setFeatureCustomers(
        bool isDineIn,
        uint8 groupSize,
        bytes32[] memory customerIDs,
        uint8[] memory genders,
        uint8[] memory age,
        uint time
    ) external {
        // Store metadata separately
        GroupFeature storage groups = mTimeToGroupFeature[time];
        groups.isDineIn = isDineIn;
        groups.groupSize = groupSize;
        groups.customerIDs = customerIDs;
        for(uint i; i<customerIDs.length;i++){
        CustomerProfile storage profile = customerProfiles[customerIDs[i]];
        profile.gender = genders[i];
        profile.ageGroup = age[i];
        if (profile.firstVisit == 0) {
            profile.firstVisit = block.timestamp;
        }
        profile.visitCount++;

        }
    }
    event OrderConfirmed(uint table, bytes32 orderId);
    function ConfirmOrder(bytes32 orderId, ORDER_STATUS _status) external onlyStaff{
        require(_status != ORDER_STATUS.UNCONFIRMED,"can not turn back status");
        SimpleCourse[] memory courses = mOrderIdToCourses[orderId];
        for (uint i = 0; i < courses.length; i++) {
            if(_status == ORDER_STATUS.CONFIRMED){
                require(courses[i].status == COURSE_STATUS.PREPARING || courses[i].status == COURSE_STATUS.CANCELED,
                "can not confirm order status CONFIRMED if course status is not preparing or cancelled status");
            }
            if(_status == ORDER_STATUS.FINISHED ){
                require(courses[i].status == COURSE_STATUS.SERVED || courses[i].status == COURSE_STATUS.CANCELED,
                "can not confirm order status FINISHED if course status is not SERVED or cancelled status");
            }
        }
        bool found = false;
        uint table;

        // 1. Update trong allOrders
        for (uint i = 0; i < allOrders.length; i++) {
            if (allOrders[i].id == orderId) {
                if(_status == ORDER_STATUS.CONFIRMED){
                    require(allOrders[i].status == ORDER_STATUS.UNCONFIRMED, "Order already confirmed or invalid");
                }
                if(_status == ORDER_STATUS.FINISHED){
                    require(allOrders[i].status == ORDER_STATUS.CONFIRMED, "Order already finished or invalid");
                }
                allOrders[i].status = _status;
                table = allOrders[i].table;
                found = true;
                break;
            }
        }
        require(found, "Order not found");

        // 2. Update trong tableOrders[table]
        Order[] storage tOrders = tableOrders[table];
        for (uint j = 0; j < tOrders.length; j++) {
            if (tOrders[j].id == orderId) {
                tOrders[j].status = _status;
                break;
            }
        }
        // 3. emit event
        emit OrderConfirmed(table, orderId);
    }

    // Main order function - drastically simplified
    function makeOrder(
        uint table,
        string[] memory dishCodes,
        uint8[] memory quantities,
        string[] memory notes,
        bytes32[] memory variantIDs
    ) external returns (bytes32 orderId) {
        require(dishCodes.length == quantities.length, "Array length mismatch");
        require(dishCodes.length <= 20, "Too many dishes"); // Limit to prevent stack issues

        // Create order
        orderId = keccak256(abi.encodePacked(table, block.timestamp, dishCodes.length));
        
        Order memory order = Order({
            id: orderId,
            table: table,
            createdAt: block.timestamp,
            status: ORDER_STATUS.UNCONFIRMED
        });
        mTableToOrderIds[table].push(order.id);
        tableOrders[table].push(order);
        // Process courses and calculate total
        uint totalPrice = _processCourses(table, orderId, dishCodes, quantities, notes,variantIDs);
        
        // Create or update payment
        _createOrUpdatePayment(table,order.id, totalPrice);
        allOrders.push(order);
        mTableToIdPayment[table] = mTableToPayment[table].id;

        emit OrderMade(table, orderId, dishCodes.length);
        return orderId;
    }
    function _processCourses(
        uint table,
        bytes32 orderId,
        string[] memory dishCodes,
        uint8[] memory quantities,
        string[] memory notes,
        bytes32[] memory variantIDs
    ) internal returns (uint totalPrice) {
        uint courseIdStart = mTableToCourses[table].length + 1;
        
        for (uint i = 0; i < dishCodes.length; i++) {
            totalPrice += _addCourse(table, orderId, courseIdStart + i, dishCodes[i], quantities[i], notes[i],variantIDs[i]);
        }
    }
    function _addCourse(
        uint table,
        bytes32 orderId,
        uint courseId,
        string memory dishCode,
        uint8 quantity,
        string memory note,
        bytes32 variantID
    ) internal returns (uint coursePrice) {
        // Get dish info
        require(quantity >0,"quantity can be zero");
        (string memory dishName, bool available, bool active, string memory imgUrl) = MANAGEMENT.GetDishBasic(dishCode);
        require(available && active, "Dish unavailable");
        Variant memory orderVariant = MANAGEMENT.getVariant(dishCode, variantID);
        require(
            orderVariant.variantID != bytes32(0),
            "Variant not found"
        );

        // require(MANAGEMENT.IsDishEnough(dishCode, quantity), "Insufficient stock");
        uint dishPrice = orderVariant.dishPrice;
        SimpleCourse memory course = SimpleCourse({
            id: courseId,
            dishCode: dishCode,
            dishName: dishName,
            dishPrice: dishPrice,
            quantity: quantity,
            status: COURSE_STATUS.ORDERED,
            imgUrl:imgUrl,
            note:note
        });
        mOrderIdToCourses[orderId].push(course);
        mTableToCourses[table].push(course);
        mTableToIdToCourse[table][course.id] = course ;
        coursePrice = dishPrice * quantity;
        mTableToCoursePrice[table][course.id] = coursePrice;
    }

    function _createOrUpdatePayment(
        uint table,
        bytes32 orderId,
        uint totalPrice
    ) internal {
        Payment storage payment = mTableToPayment[table];
        uint taxAmount = (totalPrice * taxPercent) / 100;

        if (payment.id == bytes32(0)) {
            // Create new payment
            bytes32 paymentId = keccak256(abi.encodePacked(table, block.timestamp));
            payment.id = paymentId;
            payment.tableNum = table;
            payment.foodCharge = totalPrice;
            payment.tax = taxAmount;
            payment.total = totalPrice + taxAmount;
            payment.status = PAYMENT_STATUS.CREATED;  
            payment.orderIds = mTableToOrderIds[table];
            payment.createdAt = block.timestamp;
            mTableToPayment[table] = payment;        
            mIdToPayment[paymentId] = payment;
            allPaymentIds.push(paymentId);
        } else {
            // Update existing payment
            payment.orderIds.push(orderId);
            payment.foodCharge += totalPrice;
            payment.tax += taxAmount;
            payment.total = payment.foodCharge + payment.tax + payment.tip - payment.discountAmount;
            mIdToPayment[payment.id] = payment;
        }
        // Store courses for this payment
        for(uint i; i< mOrderIdToCourses[orderId].length; i++){
            paymentCourses[payment.id].push(mOrderIdToCourses[orderId][i]);
        }
        
    }
    function UpdateOrder(
        uint _numTable,
        bytes32 _orderId,
        uint[] memory _courseIds,
        uint[] memory _quantities
    )external returns(bool){
        require(_courseIds.length == _quantities.length,"number of course id should be equal to number of quantity");
        Payment storage payment = mTableToPayment[_numTable];         
        SimpleCourse[] storage courseArr = mOrderIdToCourses[_orderId];
        SimpleCourse[] storage courses = mTableToCourses[_numTable];
        for (uint i; i < _courseIds.length; i++) {
            for (uint j = 0; j < courseArr.length; j++) {
                if (courseArr[j].id == _courseIds[i]) {
                    if(courseArr[j].quantity == _quantities[i]){
                        break;
                    }
                    if(courseArr[j].quantity > _quantities[i]){ //minus quantity
                        uint diffPrice = (courseArr[j].quantity - _quantities[i]) * courseArr[j].dishPrice;
                        payment.foodCharge -= diffPrice;
                        payment.tax -= diffPrice * taxPercent / 100;
                        payment.total -= diffPrice + diffPrice * taxPercent / 100;
                    }
                    if(courseArr[j].quantity < _quantities[i]){                              //add more quantity
                        uint diffPrice = (_quantities[i] - courseArr[j].quantity) * courseArr[j].dishPrice;
                        payment.foodCharge += diffPrice;
                        payment.tax += diffPrice * taxPercent / 100;
                        payment.total += diffPrice + diffPrice * taxPercent / 100;
                    }                 
                    courseArr[j].quantity = _quantities[i];
                    break; 
                }
            }
            for (uint j = 0; j < courses.length; j++) {
                if (courses[j].id == _courseIds[i]) {
                    courses[j].quantity = _quantities[i];
                    break; 
                }
            }
        }
        mIdToPayment[payment.id] = payment;
        for(uint i; i < _courseIds.length; i++){
            SimpleCourse storage course = mTableToIdToCourse[_numTable][_courseIds[i]];
            require(course.status == COURSE_STATUS.ORDERED,"course can not change anymore");
            course.quantity = _quantities[i];           
        }
        return true;       
    }

    function _applyDiscount(
        Payment storage payment,
        string memory discountCode
    ) internal returns (uint discountAmount) {
        if (bytes(discountCode).length == 0) return 0;
        
        (uint discountPercent, bool active, uint amountUsed, uint amountMax, uint from, uint to) = 
            MANAGEMENT.GetDiscountBasic(discountCode);
            
        require(active, "Discount inactive");
        require(amountUsed < amountMax, "Discount limit reached");
        require(block.timestamp >= from && block.timestamp <= to, "Discount expired");
        
        MANAGEMENT.UpdateDiscountCodeUsed(discountCode);
        return (payment.foodCharge * discountPercent) / 100;
    }

    // Staff functions
    function confirmPayment(
        uint table,
        bytes32 paymentId,
        string memory reason
    ) external onlyStaff returns (bool) {
        Payment storage payment = mIdToPayment[paymentId];
        require(payment.status == PAYMENT_STATUS.PAID, "Payment not paid");
        
        payment.status = PAYMENT_STATUS.CONFIRMED_BY_STAFF;        
        payment.staffConfirm = msg.sender;
        payment.reasonConfirm = reason;
        
        _clearTable(table);
        //update report
        Report.UpdateDailyStats(block.timestamp/86400, payment.total, 1);
        emit PaymentConfirmed(paymentId, msg.sender);
        return true;
    }
    event CallStaff(uint table, uint amount );
    function callStaff(uint table,uint amount) external {
        address[] memory staffsPayment = MANAGEMENT.GetStaffRolePayment();
        NotiParams memory param = NotiParams({
            title: "Customer Call",
            body: string(abi.encodePacked("table: " ,table.toString(),"amount:",amount.toString()))
        });
        // require(staffsPayment.length >0, "no staff have role PAYMENT_CONFIRM was set");
        // for(uint i; i < staffsPayment.length; i++){
        //     noti.AddNoti(param,staffsPayment[i]);
        // }
        emit CallStaff(table,amount);
    }
    event BatchCourseStatusUpdated(uint table,bytes32 _orderId,COURSE_STATUS newStatus);

    function BatchUpdateCourseStatus(
        uint table,
        bytes32 _orderId,
        COURSE_STATUS newStatus
    )external onlyStaff {
        SimpleCourse[] memory courses = mOrderIdToCourses[_orderId];
        for(uint i; i < courses.length; i++){
            if(courses[i].status == COURSE_STATUS.CANCELED || courses[i].status == COURSE_STATUS.SERVED){
                continue;
            }
            _updateCourseStatus(table,_orderId,courses[i].id,newStatus);
        }
        emit BatchCourseStatusUpdated(table,_orderId,newStatus);
    }
    event CourseStatusUpdated(uint table,bytes32 _orderId,uint _courseId,COURSE_STATUS newStatus);

    function updateCourseStatus(
        uint table,
        bytes32 _orderId,
        uint _courseId,
        COURSE_STATUS newStatus
    ) external onlyStaff {
        _updateCourseStatus(table,_orderId,_courseId,newStatus);
    }
    function _updateCourseStatus(
        uint table,
        bytes32 _orderId,
        uint _courseId,
        COURSE_STATUS newStatus
    ) internal  {
         require(newStatus != COURSE_STATUS.ORDERED,
                "course status of ORDERED autonomically set when make a new order"
        );
        SimpleCourse storage course = mTableToIdToCourse[table][_courseId];
        if (
            (newStatus == COURSE_STATUS.PREPARING && course.status != COURSE_STATUS.ORDERED) ||
            (newStatus == COURSE_STATUS.SERVED && course.status != COURSE_STATUS.PREPARING)
        ) {
            revert("Invalid Status");
        }
        
        course.status = newStatus;
        SimpleCourse[] storage coursesOrder = mOrderIdToCourses[_orderId];
        for(uint i; i < coursesOrder.length;i++){
            if (_courseId == coursesOrder[i].id){
                coursesOrder[i].status = newStatus;
                break;
            }
        }
        SimpleCourse[] storage coursesTable = mTableToCourses[table];
        for(uint i; i < coursesTable.length;i++){
            if (_courseId == coursesTable[i].id){
                coursesTable[i].status = newStatus;
                break;
            }
        }
        Payment memory payment = mTableToPayment[table];
        SimpleCourse[] storage coursesPayment = paymentCourses[payment.id] ;
        for(uint i; i < coursesPayment.length; i++){
            if (_courseId == coursesPayment[i].id){
                coursesPayment[i].status = newStatus;
                break;
            }        
        }
        emit CourseStatusUpdated(table,_orderId,_courseId,newStatus);
    }

    function _clearTable(uint table) internal {
        delete mTableToCourses[table];
        delete tableOrders[table];
        delete mTableToOrderIds[table];
        delete mTableToPayment[table];
    }

    // Execute order with VISA payment or Cash. if cash txID is emty string
    function executeOrder(
        uint table,
        string memory discountCode,
        uint tip,
        uint256 paymentAmount,
        string memory txID
    ) external whenNotPaused nonReentrant returns (bool) {
        //pay by visa
        if (bytes(txID).length !=0 ){
            require(!usedTxIds[txID], "Transaction ID already used");
            
            // Verify transaction status
            TransactionStatus memory transaction = ICARD_VISA.getTx(txID);
            require(transaction.status == TxStatus.SUCCESS, "Transaction not successful"); // 1 = SUCCESS
            
            // Verify merchant and amount
            PoolInfo memory poolInfo = ICARD_VISA.getPoolInfo(txID);
            require(poolInfo.ownerPool == merchant, "Merchant address mismatch");
            require(poolInfo.parentValue == paymentAmount,"amount not matched");
        }
        
        // Process payment
        Payment storage payment = mTableToPayment[table];
        require(payment.status == PAYMENT_STATUS.CREATED, "Invalid payment status");
        
        // Apply discount
        uint discountAmount = _applyDiscount(payment, discountCode);
        
        // Update payment
        payment.tip = tip;
        payment.discountAmount = discountAmount;
        payment.total = payment.foodCharge + payment.tax + payment.tip - payment.discountAmount;
        
        require(paymentAmount >= payment.total, "Insufficient payment amount");
        
        payment.status = PAYMENT_STATUS.PAID;
        payment.createdAt = block.timestamp;
        
        // Update metadata
        Payment storage meta = mTableToPayment[table];
        if (bytes(txID).length !=0 ){
            meta.method = "VISA";
        } else {
            meta.method = "CASH";
        }
        meta.discountCode = discountCode;
        
        mIdToPayment[payment.id] = payment;
        mIdToPayment[payment.id] = meta;
        
        // Mark transaction as used
        usedTxIds[txID] = true;
        
        paymentHistory.push(payment);
        //update orderNum of Dish for getTop 
        //FE gọi sau vì goi cùng sẽ bị lỗi out of gas
        // for (uint i = 0; i < mTableToCourses[table].length; i++) {
        //     SimpleCourse memory course = mTableToCourses[table][i];
        //     MANAGEMENT.UpdateOrderNum(course.dishCode,course.quantity,block.timestamp);
        //     uint dishPrice = mTableToCoursePrice[table][course.id];
        //     Report.UpdateDishDailyData(course.dishCode,block.timestamp,dishPrice,1); //1 là 1 order
        // }
        // MANAGEMENT.UpdateTotalRevenueReport(block.timestamp,payment.foodCharge-payment.discountAmount); //FE gọi sau để không bị out of gas
        //  MANAGEMENT.SortDishesWithOrderRange //FE gọi sau để không bị out of gas
        //  MANAGEMENT.UpdateRankDishes //FE gọi sau để không bị out of gas
        emit PaymentMade(table, payment.id, payment.total);
        return true;
    }
    function UpdateForReport(uint table) external {
        for (uint i = 0; i < mTableToCourses[table].length; i++) {
            SimpleCourse memory course = mTableToCourses[table][i];
            if(course.quantity>0){
                MANAGEMENT.UpdateOrderNum(course.dishCode,course.quantity,block.timestamp);
                uint dishPrice = mTableToCoursePrice[table][course.id];
                Report.UpdateDishDailyData(course.dishCode,block.timestamp,dishPrice,1); //1 là 1 order

            }
        }

    }
    function getPaymentCourses(bytes32 _paymentID) external view returns(SimpleCourse[] memory courses, Payment memory payment){
        return (paymentCourses[_paymentID],mIdToPayment[_paymentID]);
    }


    // Review function
    function makeReview(
        bytes32 paymentId,
        uint8 overalStar,
        string[] memory dishCodes,
        uint8[] memory dishStars,
        string memory contribution,
        string memory nameCustomer
    ) external returns (bool) {
        require(mIdToPayment[paymentId].id != bytes32(0), "Payment not found");
        require(overalStar >= 1 && overalStar <= 5, "Invalid food rating");
        bytes32 id = keccak256(abi.encodePacked(block.timestamp,paymentId,contribution));
        for (uint i = 0; i < dishCodes.length; i++) {
            DishReview memory dishReview = DishReview({
                nameCustomer: nameCustomer,
                dishCode: dishCodes[i],
                dishStar: dishStars[i],
                contribution: contribution,
                createdAt: block.timestamp,
                paymentId: paymentId,
                isShow: true,
                id: id
            });
            mDishCodeToReviews[dishCodes[i]].push(dishReview);
            mDishReviewIndex[dishCodes[i]][id] = mDishCodeToReviews[dishCodes[i]].length - 1;
            MANAGEMENT.updateAverageStarDish(dishStars[i],dishCodes[i]);
        }

        reviews[paymentId] = Review({
            nameCustomer: nameCustomer,
            overalStar: overalStar,
            contribution: contribution,
            createdAt: block.timestamp,
            paymentId: paymentId
        });
                // Lưu review theo date
        uint256 date = block.timestamp / 86400;
        reviewsByDate[date].push(reviews[paymentId]);

        return true;
    }
        // Hàm lấy reviews theo date
    function getReviewsByDate(
        uint256 date,
        uint256 page,
        uint256 pageSize
    ) external view returns (Review[] memory,uint256 totalCount,uint256 totalPages,uint256 currentPage) {
        require(pageSize > 0, "Page size must be greater than 0");
        require(page > 0, "Page must be greater than 0");
        
        Review[] storage allReviews = reviewsByDate[date];
        totalCount = allReviews.length;
        
        // Tính tổng số trang
        totalPages = (totalCount + pageSize - 1) / pageSize;
        
        // Nếu không có dữ liệu
        if (totalCount == 0) {
            return (new Review[](0), 0, 0, page);
        }
        
        // Nếu page vượt quá totalPages
        if (page > totalPages) {
            return (new Review[](0), totalCount, totalPages, page);
        }
        
        // Tính start và end index
        uint256 startIndex = (page - 1) * pageSize;
        uint256 endIndex = startIndex + pageSize;
        
        if (endIndex > totalCount) {
            endIndex = totalCount;
        }
        
        // Tạo mảng kết quả
        uint256 resultSize = endIndex - startIndex;
        Review[] memory result = new Review[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            result[i] = allReviews[startIndex + i];
        }
        
        return (result, totalCount, totalPages, page);
    }

    function BatchUpdateHideReview(bytes32[] memory reviewIds, string memory dishCode) external {
        require(reviewIds.length >0,"reviewid array can be empty");  
        for(uint i; i < reviewIds.length; i++){
            _hideReview(reviewIds[i],dishCode);
        }
    }
    function _hideReview(bytes32 reviewId, string memory dishCode) internal {
        uint index = mDishReviewIndex[dishCode][reviewId];
        DishReview storage review = mDishCodeToReviews[dishCode][index];
        review.isShow = false;
    }
    function getReviewByDish(string memory dishCodes) external view returns (DishReview[] memory) {
        return mDishCodeToReviews[dishCodes];
    }
    // View functions - return simple data only
    function getTableOrderCount(uint table) external view returns (uint) {
        return tableOrders[table].length;
    }
    function GetOrders(uint _numTable)external view returns(Order[] memory ){
        return tableOrders[_numTable];
    }

    function getTableCourseCount(uint table) external view returns (uint) {
        return mTableToCourses[table].length;
    }

    function getTableOrder(uint table, uint index) external view returns (Order memory) {
        require(index < tableOrders[table].length, "Index out of bounds");
        return tableOrders[table][index];
    }

    function getTableCourse(uint table, uint index) external view returns (SimpleCourse memory) {
        require(index < mTableToCourses[table].length, "Index out of bounds");
        return mTableToCourses[table][index];
    }
    function GetCoursesByTable(uint _numTable)external view returns(SimpleCourse[]memory){
        return mTableToCourses[_numTable];
    }
    function GetAllOrders()external view returns(Order[] memory){
        return allOrders;
    }

    function GetCoursesByOrderId(bytes32 _idOrder) external view returns(SimpleCourse[] memory){
        return mOrderIdToCourses[_idOrder];
    }
    function getPayment(bytes32 paymentId) external view returns (Payment memory) {
        return mIdToPayment[paymentId];
    }

    function getTablePayment(uint table) external view returns (Payment memory) {
        Payment memory payment = mTableToPayment[table];
        return payment;
    }
    function GetLastIdPaymentByTable(uint _numTable)external view returns(bytes32){
        return mTableToIdPayment[_numTable];
    }

    function getReview(bytes32 paymentId) external view returns (Review memory) {
        return reviews[paymentId];
    }

    function getPaymentHistoryCount() external view returns (uint) {
        return paymentHistory.length;
    }

    function getPaymentHistoryItem(uint index) external view returns (Payment memory) {
        require(index < paymentHistory.length, "Index out of bounds");
        return paymentHistory[index];
    }
    function getPaymentsWithStatus(uint offset, uint limit)external view returns (Payment[] memory payments, uint totalCount) {
        for(uint i; i < paymentHistory.length; i++){

        }
        uint paymentCount = paymentHistory.length;
        totalCount = paymentCount;
        
        if (paymentCount == 0 || offset >= paymentCount) {
            return (new Payment[](0), totalCount);
        }
        
        // Tính toán số lượng thực tế cần lấy
        uint remainingItems = paymentCount - offset;
        if (limit > remainingItems) {
            limit = remainingItems;
        }
        if (limit == 0) {
            return (new Payment[](0), totalCount);
        }
        
        // Sử dụng insertion sort đơn giản và đáng tin cậy
        return (_getPaymentsNotPaid(offset, limit));
    }
    function _getPaymentsNotPaid(uint offset, uint limit) internal view returns (Payment[] memory payments, uint totalCount) {
        uint paymentCount = paymentHistory.length;
    
        // Tạo mảng tất cả dishes với orderNum
        Payment[] memory paymentsNotPaid = new Payment[](paymentCount);
        uint count;
        for(uint i; i<paymentCount; i++){
            if(paymentHistory[i].status == PAYMENT_STATUS.CREATED){
                paymentsNotPaid[count] = paymentHistory[i];
                count++;
            }
        }
        // Lấy kết quả từ offset
        Payment[] memory result = new Payment[](limit);
        for (uint i = 0; i < limit; i++) {
            result[i] = paymentsNotPaid[offset + i];
        }      
        return (result,paymentCount);
    }
    struct PaymentInfo {
        Payment payment;
        SimpleCourse[] courses;
    } 
    function getPaymentsPagination(uint offset, uint limit)external view returns (PaymentInfo[] memory payments, uint totalCount) {
        for(uint i; i < allPaymentIds.length; i++){

        }
        uint paymentCount = allPaymentIds.length;
        totalCount = paymentCount;
        
        if (paymentCount == 0 || offset >= paymentCount) {
            return (new PaymentInfo[](0), totalCount);
        }
        
        // Tính toán số lượng thực tế cần lấy
        uint remainingItems = paymentCount - offset;
        if (limit > remainingItems) {
            limit = remainingItems;
        }
        if (limit == 0) {
            return (new PaymentInfo[](0), totalCount);
        }
        
        // Sử dụng insertion sort đơn giản và đáng tin cậy
        return (_getPayments(offset, limit));
    }
    function _getPayments(uint offset, uint limit) internal view returns (PaymentInfo[] memory payments, uint totalCount) {
        uint paymentCount = allPaymentIds.length;
    
        // Lấy kết quả từ offset
        PaymentInfo[] memory result = new PaymentInfo[](limit);
        for (uint i = 0; i < limit; i++) {            
            result[i] = PaymentInfo({
                payment : mIdToPayment[allPaymentIds[offset + i]],
                courses : paymentCourses[allPaymentIds[offset + i]]
            });
            
        }      
        return (result,paymentCount);
    }
    function getTaxPercent() external view returns (uint8) {
        return taxPercent;
    }

}