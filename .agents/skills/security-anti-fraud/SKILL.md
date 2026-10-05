---
name: Security, Anti-Fraud & Vulnerability Prevention
description: Hướng dẫn toàn diện về bảo mật, chống gian lận (Anti-fraud), kiểm soát giao dịch tài chính, chống GPS giả mạo và phòng ngừa các lỗ hổng bảo mật cho nền tảng gọi xe & giao hàng.
---

# Security, Anti-Fraud & Vulnerability Prevention

## 1. Khi nào dùng skill này?
- Thiết kế hoặc kiểm tra bất kỳ API, cơ sở dữ liệu hay luồng nghiệp vụ liên quan đến:
  - Xác thực (Auth), phân quyền (RBAC/ABAC).
  - Đặt xe, nhận cuốc, hủy chuyến, cập nhật trạng thái đơn hàng.
  - Thanh toán ví tiền, cấn trừ số dư, hoàn tiền (Refund), tính cước chuyến đi.
  - Cập nhật tọa độ GPS tài xế, phát hiện gian lận vị trí (Mock GPS/Spoofing).
  - Bảo vệ dữ liệu cá nhân (PII), chống lộ số điện thoại và địa chỉ nhạy cảm.

---

## 2. Các Lỗ Hổng Phổ Biến & Giải Pháp Chống Đỡ (Vulnerabilities & Mitigations)

### 2.1. Race Condition khi nhận cuốc xe (Double-Dispatch / Multi-Accept)
- **Rủi ro**: 2 tài xế cùng bấm "Nhận cuốc" tại cùng 1 mili-giây, dẫn đến cả 2 tài xế cùng được gán cho 1 cuốc xe.
- **Giải pháp**:
  1. **Ở tầng Database (Optimistic Locking)**:
     ```sql
     UPDATE orders
     SET driver_id = $1, status = 'accepted', accepted_at = NOW(), updated_at = NOW()
     WHERE id = $2 AND status = 'created';
     ```
     Kiểm tra `RowsAffected()`: Nếu trả về `0`, nghĩa là cuốc xe đã bị tài xế khác nhận trước. Trả về ngay lỗi `409 Conflict` ("Cuốc xe đã được tài xế khác tiếp nhận").
  2. **Ở tầng Redis (Distributed Lock)**:
     Trước khi xử lý, giữ lock với thời hạn ngắn:
     ```go
     ok, err := redisClient.SetNX(ctx, "lock:order:"+orderID, driverID, 5*time.Second).Result()
     if !ok {
         return ErrOrderAlreadyClaimed
     }
     ```

---

### 2.2. Gian Lận Tài Chính & Double-Spending (Thanh toán & Ví điện tử)
- **Rủi ro**:
  - Khách hàng bấm gửi nhiều lần khiến bị trừ tiền 2 lần hoặc hưởng khuyến mãi 2 lần.
  - Số dư ví bị âm khi phát sinh 2 yêu cầu rút tiền song song.
  - Giả mạo webhook thanh toán từ cổng trung gian (VNPay, MoMo).
- **Giải pháp**:
  1. **Bắt buộc dùng `X-Idempotency-Key`**:
     Mọi request tạo cuốc xe (`POST /rides`), nạp tiền, hoặc thanh toán đều phải gửi kèm header `X-Idempotency-Key: <UUID>`. Lưu key này vào bảng `orders` hoặc Redis với TTL 24h. Nếu request trùng key được gửi lại, trả về kết quả cũ mà không thực thi lại.
  2. **Trừ tiền ví nguyên tử (Atomic Balance Deduction)**:
     ```sql
     UPDATE wallets
     SET balance = balance - $1, updated_at = NOW()
     WHERE user_id = $2 AND balance >= $1
     RETURNING balance;
     ```
     Tuyệt đối không đọc `balance` ra Go rồi tính toán rồi `UPDATE` mà không có lock (tránh TOCTOU - Time of check to time of use).
  3. **Xác thực chữ ký số Webhook**:
     Mọi callback thanh toán từ MoMo/VNPay/ZaloPay BẮT BUỘC phải kiểm tra chữ ký HMAC-SHA256 với Secret Key bí mật trước khi cập nhật `orders.payment_status = 'paid'`.

---

### 2.3. Gian Lận Vị Trí & GPS Giả Mạo (Mock GPS Spoofing)
- **Rủi ro**: Tài xế dùng ứng dụng Fake GPS để nhận cuốc xe từ xa hoặc gian lận quãng đường nhằm tăng tiền cước.
- **Giải pháp**:
  1. **Kiểm tra dị thường tốc độ (Speed Anomaly & Teleportation Detection)**:
     ```go
     // Khoảng cách giữa 2 điểm liên tiếp (km)
     dist := haversineDistance(prevLat, prevLng, newLat, newLng)
     timeDiffHours := newTime.Sub(prevTime).Hours()
     if timeDiffHours > 0 {
         speedKmh := dist / timeDiffHours
         if speedKmh > 130.0 { // Tốc độ vượt ngưỡng thực tế xe máy/ô tô đô thị
             flagDriverSuspicious(driverID, "SPEED_ANOMALY", speedKmh)
             return ErrInvalidLocationTelemetry
         }
     }
     ```
  2. **Phát hiện Mock Location từ Mobile SDK**:
     - Android: Kiểm tra `location.isFromMockProvider()`.
     - iOS: Kiểm tra `location.sourceInformation?.isSimulatedBySoftware`.
     Nếu phát hiện giả lập, từ chối cập nhật tọa độ lên server.
  3. **Chốt giá cước trước (Upfront Fare Pricing)**:
     Cước xe được tính toán cố định dựa trên lộ trình chuẩn của Routing Engine (Goong/Mapbox) lúc đặt xe, tránh việc tài xế cố tình đi đường vòng để tăng đồng hồ cước.

---

### 2.4. IDOR (Insecure Direct Object Reference) & Phân Quyền Vai Trò
- **Rủi ro**:
  - Tài xế tự nhận cuốc do chính mình đặt (tự book tự hủy để trục lợi voucher/thưởng cuốc).
  - Tài xế A cập nhật chuyến đi của tài xế B.
  - Khách hàng xem lịch sử chuyến đi của người khác bằng cách thay đổi `order_id` trên URL.
- **Giải pháp**:
  1. **Không cho phép tự nhận cuốc xe của chính mình**:
     ```go
     if order.CustomerID == currentUserID {
         return ErrCannotAcceptOwnRide
     }
     ```
  2. **Xác thực chủ quyền bản ghi (Ownership Enforcement)**:
     - Khi tài xế gọi `POST /driver/trip/update`:
       ```sql
       UPDATE orders SET status = $1
       WHERE id = $2 AND driver_id = $3; -- $3 là driverID lấy từ JWT Claim, không lấy từ client Body
       ```
     - Khi khách hàng gọi `GET /rides/:id`:
       ```sql
       SELECT * FROM orders WHERE id = $1 AND customer_id = $2;
       ```

---

### 2.5. Bảo Vệ Dữ Liệu Cá Nhân & Quyền Riêng Tư (PII Protection)
- **Rủi ro**: Tài xế quấy rối khách hàng sau chuyến đi hoặc bán số điện thoại khách hàng.
- **Giải pháp**:
  1. **Ẩn số điện thoại (Number Masking)**:
     - Trên màn hình app sau khi chuyến xe hoàn thành: Che số điện thoại (`090****567`).
     - Tích hợp cuộc gọi VoIP nội bộ qua WebRTC hoặc số điện thoại ảo tổng đài (Virtual Proxy Number).
  2. **Xóa dữ liệu chat theo thời hạn (Ephemeral Chat)**:
     Tin nhắn trao đổi trong chuyến đi tự động đánh dấu lưu trữ và vô hiệu hóa sau khi chuyến đi kết thúc 24 giờ.

---

### 2.6. Chống Tấn Công Injection & Kiểm Tra Tọa Độ PostGIS
- **Rủi ro**: Client truyền tọa độ không hợp lệ (`NaN`, `Infinity`, tọa độ ngoài trái đất) gây sập engine PostGIS hoặc SQL Injection.
- **Giải pháp**:
  1. **Luôn kiểm tra biên tọa độ (Bounds Validation)**:
     ```go
     func ValidateCoordinate(lat, lng float64) error {
         if math.IsNaN(lat) || math.IsNaN(lng) || math.IsInf(lat, 0) || math.IsInf(lng, 0) {
             return errors.New("invalid coordinate values")
         }
         if lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0 {
             return errors.New("coordinates out of earthly bounds")
         }
         return nil
     }
     ```
  2. **100% dùng Parameterized Queries (`$1`, `$2`)**:
     Tuyệt đối không ghép chuỗi SQL dạng `fmt.Sprintf("SELECT * FROM ... WHERE id = '%s'", id)`.

---

## 3. Checklist An Ninh Trước Khi Đưa Code Lên Production

- [ ] Tất cả endpoint nhạy cảm đều có middleware xác thực JWT và kiểm tra Role (`rider`, `driver`, `admin`).
- [ ] Bắt buộc có `X-Idempotency-Key` cho mọi thao tác tạo đơn hoặc giao dịch tiền bạc.
- [ ] Query cập nhật trạng thái đơn hàng đều kiểm tra đúng ID của tài xế được phân công (`driver_id = jwt.UserID`).
- [ ] Không trả về thông tin mật (password hash, internal server logs, database stack trace) ra response client.
- [ ] Mọi input tọa độ đều đi qua hàm kiểm tra phạm vi vĩ độ/kinh độ hợp lệ.
- [ ] Bật Rate Limiting trên API Gateway (Token bucket: 60 req/min cho public API, 5 req/min cho OTP/Login).
