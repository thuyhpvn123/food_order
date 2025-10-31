// SPDX-License-Identifier: SEE LICENSE IN LICENSE
import {Discount} from "./IRestaurant.sol";
pragma solidity ^0.8.20; 
    struct RegisterInPut{
        string _memberId;
        string _phoneNumber;
        string _firstName;
        string _lastName;
        string _whatsapp;
        string _email;
        string _avatar;
    }
    struct Member {
        string memberId;           // Mã thành viên tự đặt (8-12 ký tự)
        address walletAddress;     // Địa chỉ ví MetaNode
        uint256 totalPoints;       // Tổng điểm hiện có
        uint256 lifetimePoints;    // Tổng điểm tích lũy suốt đời
        uint256 totalSpent;        // Tổng chi tiêu (VND)
        bytes32 tierID;                 // Hạng thành viên
        // uint256 tierUpdatedAt;     // Thời gian cập nhật hạng
        uint256 lastBuyActivityAt;    // Lần tương tác cuối
        bool isActive;             // Trạng thái tài khoản
        bool isLocked;             // Khóa tài khoản (nghi ngờ gian lận)
        string phoneNumber;        // Số điện thoại (optional)
        string firstName;           // Họ tên (optional)
        string lastName;
        string whatsapp;
        string email;
        string avatar;
    }
    struct MemberVoucher {
        string code;
        uint256 redeemedAt;
        bool isUsed;
        uint256 usedAt;
        Discount voucherDetail;
    }
    struct Transaction {
        uint256 id;                // Mã giao dịch
        address member;            // Địa chỉ ví thành viên
        TransactionType txType;    // Loại giao dịch
        int256 points;             // Số điểm (+/-)
        uint256 amount;            // Số tiền giao dịch (VND)
        bytes32 invoiceId;          // Mã hóa đơn
        address processedBy;       // Người xử lý (nhân viên/admin)
        uint256 timestamp;         // Thời gian
        string note;               // Ghi chú
        uint256 eventId;           // ID sự kiện (nếu có)
        PointTransactionStatus status;  // Trạng thái
    }
    
    struct Event {
        uint256 id;                // ID sự kiện
        string name;               // Tên sự kiện
        uint256 startTime;         // Thời gian bắt đầu
        uint256 endTime;           // Thời gian kết thúc
        uint256 pointPlus;        // Hệ số nhân (100 = 1x, 200 = 2x)
        bytes32 minTierID;              // Hạng tối thiểu
        bool isActive;             // Trạng thái kích hoạt
    }
    
    // struct Reward {
    //     uint256 id;                // ID quà tặng
    //     string name;               // Tên quà
    //     uint256 pointsCost;        // Số điểm cần đổi
    //     bytes32 minTierID;              // Hạng tối thiểu
    //     uint256 quantity;          // Số lượng còn lại
    //     bool isActive;             // Trạng thái
    //     string description;        // Mô tả
    // }
    
    struct TierConfig {
        bytes32 id;
        string nameTier;
        uint256 pointsRequired;    // Điểm yêu cầu
        uint256 pointsMax;
        uint256 multiplier;        // Hệ số thưởng (100 = 1x)
        // uint256 validityPeriod;    // Thời hạn giữ hạng (giây)
        string colour;
    }
    
    struct PointIssuance {
        uint256 id;                // ID đợt phát hành
        uint256 amount;            // Số lượng xu phát hành
        address issuedBy;          // Người phát hành
        uint256 timestamp;         // Thời gian
        string name;               // Ghi chú
        // IssuanceStatus status;     // Trạng thái
        uint accumulationPercent; //Tỷ lệ tích điểm 
        uint maxPercentPerInvoice; //Hạn mmức sử dụng mỗi bill
    }
    
    struct ManualRequest {
        uint256 id;                // ID yêu cầu
        address member;            // Thành viên
        bytes32 invoiceId;          // Mã hóa đơn
        uint256 amount;            // Số tiền
        uint256 pointsToEarn;      // Điểm sẽ nhận
        address requestedBy;       // Nhân viên yêu cầu
        uint256 requestTime;       // Thời gian yêu cầu
        RequestStatus status;      // Trạng thái
        address approvedBy;        // Người duyệt
        uint256 approvedTime;      // Thời gian duyệt
        string rejectReason;       // Lý do từ chối
        RequestEarnPointType typeRequest;               // Mô tả
        string img;
    }
    struct MemberGroup {
        bytes32 id;
        string name;
        bool isActive;
    }
    struct PaymentTransaction {
        bytes32 paymentId;
        uint256 pointsUsed;
        uint256 orderAmount;
        uint256 timestamp;
    }
    // ============ ENUMS ============
    
    enum RequestEarnPointType {
        OldBill,
        GGReview,
        FBShare
    }
    enum TransactionType {
        Issue,          //Phát hành
        Earn,           // Tích điểm
        Redeem,         // Đổi điểm
        ManualAdjust,   // Điều chỉnh thủ công
        Expire,         // Hết hạn
        Refund,          // Hoàn điểm
        Transfer
    }
    
    enum PointTransactionStatus {
        Pending,    // Chờ xử lý
        Approved,   // Đã duyệt
        Rejected,   // Bị từ chối
        Completed   // Hoàn thành
    }
    
    // enum IssuanceStatus {
    //     Processing, // Đang xử lý
    //     Success,    // Thành công
    //     Failed      // Thất bại
    // }
    
    enum RequestStatus {
        Pending,    // Chờ duyệt
        Approved,   // Đã duyệt
        Rejected    // Bị từ chối
    }
    
    enum Role {
        None,       // Không có quyền
        Staff,      // Nhân viên
        Admin       // Quản trị viên
    }
    
interface IPoint {
    function getMemberToGroup(address _member) external view returns (bytes32);
    function redeemVoucherPoints(address _member, uint256 _pointCost) external;
    function getPaymentConfig() external view returns (uint256 exchangeRate,uint256 maxPercentPerInvoice);
     function getMember(address _member) external view returns (
        string memory memberId,
        uint256 totalPoints,
        uint256 lifetimePoints,
        uint256 totalSpent,
        bytes32 tierID,
        string memory tierName,
        bool isActive,
        bool isLocked,
        uint256 lastBuyActivityAt,
        string memory phoneNumber,
        string memory email
    ) ;
    function usePointsForPayment(
        address _member,
        uint256 _pointsToUse,
        uint256 _orderAmount
    ) external ;
    function isMemberGroupId(bytes32 groupId) external view returns (bool);
    function isMemberPointSystem(address _user) external view returns (bool);
    function updateLastBuyActivityAt(address user) external;
    function initialize(
        address _agent,
        address _enhancedAgentSC
    ) external;
    function setManagementSC(address _management)external;
    function setOrder(address _order)external;
    function transferOwnership(address newOwner) external ;
}