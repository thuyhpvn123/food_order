// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20; 
    struct Member {
        string memberId;           // Mã thành viên tự đặt (8-12 ký tự)
        address walletAddress;     // Địa chỉ ví MetaNode
        uint256 totalPoints;       // Tổng điểm hiện có
        uint256 lifetimePoints;    // Tổng điểm tích lũy suốt đời
        uint256 totalSpent;        // Tổng chi tiêu (VND)
        Tier tier;                 // Hạng thành viên
        uint256 tierUpdatedAt;     // Thời gian cập nhật hạng
        uint256 lastActivityAt;    // Lần tương tác cuối
        bool isActive;             // Trạng thái tài khoản
        bool isLocked;             // Khóa tài khoản (nghi ngờ gian lận)
        string phoneNumber;        // Số điện thoại (optional)
        string fullName;           // Họ tên (optional)
    }
    
    struct Transaction {
        uint256 id;                // Mã giao dịch
        address member;            // Địa chỉ ví thành viên
        TransactionType txType;    // Loại giao dịch
        int256 points;             // Số điểm (+/-)
        uint256 amount;            // Số tiền giao dịch (VND)
        string invoiceId;          // Mã hóa đơn
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
        uint256 multiplier;        // Hệ số nhân (100 = 1x, 200 = 2x)
        Tier minTier;              // Hạng tối thiểu
        bool isActive;             // Trạng thái kích hoạt
        uint256 maxPointsPerInvoice; // Giới hạn điểm tối đa/hóa đơn
        uint256 maxPointsPerMember;  // Giới hạn điểm tối đa/khách
        string description;        // Mô tả
    }
    
    struct Reward {
        uint256 id;                // ID quà tặng
        string name;               // Tên quà
        uint256 pointsCost;        // Số điểm cần đổi
        Tier minTier;              // Hạng tối thiểu
        uint256 quantity;          // Số lượng còn lại
        bool isActive;             // Trạng thái
        string description;        // Mô tả
    }
    
    struct TierConfig {
        uint256 pointsRequired;    // Điểm yêu cầu
        uint256 multiplier;        // Hệ số thưởng (100 = 1x)
        uint256 validityPeriod;    // Thời hạn giữ hạng (giây)
    }
    
    struct PointIssuance {
        uint256 id;                // ID đợt phát hành
        uint256 amount;            // Số lượng xu phát hành
        address issuedBy;          // Người phát hành
        uint256 timestamp;         // Thời gian
        string note;               // Ghi chú
        IssuanceStatus status;     // Trạng thái
    }
    
    struct ManualRequest {
        uint256 id;                // ID yêu cầu
        address member;            // Thành viên
        string invoiceId;          // Mã hóa đơn
        uint256 amount;            // Số tiền
        uint256 pointsToEarn;      // Điểm sẽ nhận
        address requestedBy;       // Nhân viên yêu cầu
        uint256 requestTime;       // Thời gian yêu cầu
        RequestStatus status;      // Trạng thái
        address approvedBy;        // Người duyệt
        uint256 approvedTime;      // Thời gian duyệt
        string rejectReason;       // Lý do từ chối
        string note;               // Ghi chú
    }
    
    // ============ ENUMS ============
    
    enum Tier { 
        None,      // Chưa có hạng
        Silver,    // Bạc
        Gold,      // Vàng
        Platinum   // Bạch kim
    }
    
    enum TransactionType {
        Earn,           // Tích điểm
        Redeem,         // Đổi điểm
        ManualAdjust,   // Điều chỉnh thủ công
        Expire,         // Hết hạn
        Refund          // Hoàn điểm
    }
    
    enum PointTransactionStatus {
        Pending,    // Chờ xử lý
        Approved,   // Đã duyệt
        Rejected,   // Bị từ chối
        Completed   // Hoàn thành
    }
    
    enum IssuanceStatus {
        Processing, // Đang xử lý
        Success,    // Thành công
        Failed      // Thất bại
    }
    
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
    
