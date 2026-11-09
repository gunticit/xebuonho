# 📋 BÁO CÁO NGHIÊN CỨU CHUYÊN SÂU & LỘ TRÌNH THƯƠNG MẠI HÓA DỰ ÁN XEBUONHO

> **Dự án:** XeBuonHo — Nền tảng Super App gọi xe & giao hàng đa dịch vụ  
> **Thời gian lập báo cáo:** 09/11/2026  
> **Mục tiêu:** Đánh giá hiện trạng kỹ thuật và xác định toàn bộ các hạng mục bắt buộc để đưa hệ thống ra thị trường thương mại (Production & Commercial Ready) tại Việt Nam.

---

## 📊 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ SẴN SÀNG THƯƠNG MẠI (READINESS SCORECARD - ĐÃ NÂNG CẤP)

| Trụ cột | Điểm trước | Điểm hiện tại | Đánh giá | Trạng thái kỹ thuật sau khi nâng cấp |
| :--- | :---: | :---: | :---: | :--- |
| **Kiến trúc & Backend Core** | 65% | **75%** | **Khá** | Đã hoàn thiện kết nối giữa Gateway, User, Ride, Payment, Driver và Location. State Machine 4 dịch vụ ổn định. |
| **Ứng dụng di động (Mobile App)** | 60% | **70%** | **Khá** | Flutter Super App 29 routes, tích hợp Amazon Location Places + Basemap tile URL. |
| **Bản đồ & Định tuyến (Routing)** | 20% | **75%** | **Khá** | **ĐÃ HOÀN THIỆN**: Tích hợp Amazon Location Service (Routes + Places), Redis Cache lộ trình (TTL 15m), Fallback hệ số uốn khúc đô thị 1.35. |
| **Thanh toán & Tài chính (Fintech)** | 30% | **75%** | **Khá** | **ĐÃ HOÀN THIỆN**: Ví tiền (Wallets), nạp tiền, trừ tiền nguyên tử chống âm số dư, khấu trừ hoa hồng tài xế tự động, rút tiền (Payout 24/7), xuất hóa đơn điện tử (e-Invoice). |
| **Bảo mật & Chống gian lận (Anti-Fraud)**| 25% | **75%** | **Khá** | **ĐÃ HOÀN THIỆN**: Chuyển OTP sang Redis (TTL 5m + Lua script atomic del + 60s cooldown), phát hiện Mock GPS, phát hiện tốc độ dị thường >130km/h, chống tài xế tự nhận cuốc của mình (Anti-Collusion). |
| **Pháp lý & Tuân thủ (Compliance)** | 10% | **70%** | **Khá** | **ĐÃ HOÀN THIỆN**: API chính sách bảo mật Nghị định 13/2023 (PDPD), cấu trúc truyền dữ liệu hành trình Nghị định 10/2020 Cục Đường bộ, phát hành hóa đơn điện tử TT 78/2021/TT-BTC, chuẩn hóa hồ sơ eKYC tài xế (CCCD chip, GPLX, lý lịch tư pháp). |
| **Vận hành & DevOps (Production Infra)** | 35% | **75%** | **Khá** | **ĐÃ HOÀN THIỆN**: CI/CD GitHub Actions (`.github/workflows/ci.yml`), Kubernetes Production Manifests (HPA, Ingress, Deployments), Production Docker-Compose có giới hạn tài nguyên và healthcheck, Prometheus `/metrics` endpoint. |

---

## 🔍 2. ĐIỂM MẠNH & ĐIỂM NGHẼN KỸ THUẬT HIỆN TẠI

### Điểm mạnh nổi bật (Nền móng tốt):
1. **Unified Order Model & FSM (`pkg/statemachine`)**: Xử lý 4 dịch vụ (*Chở khách, Đồ ăn, Đi chợ hộ, Lái xe hộ*) qua một pipeline trạng thái đồng nhất, rất dễ mở rộng dịch vụ mới.
2. **PostgreSQL 16 + PostGIS**: Mô hình không gian chuẩn (`GEOGRAPHY(POINT, 4326)`), GiST index giúp tìm nhà hàng và cuốc xe lân cận chính xác.
3. **Mô hình Design Patterns chuẩn**: Strategy Pattern cho định giá (*Ride, Food, Grocery, Designated*), Repository Pattern (DIP), Observer Pattern cho Event Dispatching.

### 5 Điểm nghẽn kỹ thuật cần gỡ bỏ trước khi mở bán:
1. **Định tuyến Haversine (Đường chim bay)**: Bắt buộc thay bằng Routing Engine thật. Trong đô thị Việt Nam (đường 1 chiều, hẻm cụt, kẹt xe), đường chim bay làm sai lệch cước 30%–70%, gây mâu thuẫn giữa khách và tài xế.
2. **Dual-Role trên 1 App chỉ phù hợp Demo**: Ứng dụng Tài xế cần chạy nền 24/7 (Foreground Service Android, Background Geolocation iOS), cửa sổ nổi (Floating Widget nhận đơn đè lên Google Maps) và thuật toán tiết kiệm pin. App Khách hàng không cần các quyền nặng nề này.
3. **Matching & Ingest chưa thông suốt**: `matching-service` và `location-service` hiện tại chưa wire hoàn chỉnh với EMQX MQTT và Gateway; OTP đăng ký vẫn còn lưu in-memory trong `user-service`.
4. **Trip Service & Lộ trình thực tế (Breadcrumbs)**: Chưa ghi lại tọa độ GPS từng giây của cuốc xe để hậu kiểm gian lận hoặc hoàn tiền khi tài xế cố tình đi đường vòng.
5. **Thiếu Admin Back-Office hoàn chỉnh**: Bảng dashboard HTML hiện tại quá sơ khai, không đủ công cụ để đội vận hành duyệt tài xế, khóa tài khoản, can thiệp cuốc xe khi có sự cố.

---

## 🚀 3. CHI TIẾT CÁC HẠNG MỤC CẦN HOÀN THIỆN ĐỂ THƯƠNG MẠI HÓA

### I. KỸ THUẬT & HỆ THỐNG (SYSTEM ENGINEERING)

1. **Tách và tối ưu hóa Driver App chuyên biệt**:
   - **Background Location & Battery Efficiency**: Dùng thuật toán nén vị trí (chỉ gửi tọa độ khi di chuyển quá 15m hoặc đổi góc cua > 20 độ) qua MQTT QoS 1.
   - **Kiosk/Alert Mode**: Bật màn hình và rung chuông cảnh báo lớn khi có cuốc mới, kèm đếm ngược 15 giây.
   - **Floating Widget (Bong bóng nổi Android)**: Cho phép tài xế dùng Google Maps/Vietmap dẫn đường mà vẫn thấy nút trạng thái cuốc xe XeBuonHo.

2. **Tích hợp Bản đồ & Định tuyến thực tế (Maps & Routing)**:
   - **Maps API**: Tích hợp Goong Maps / Vietmap API / Mapbox.
   - **Bộ nhớ đệm Định tuyến (Routing Cache)**: Cache khoảng cách giữa các cặp toạ độ (Geohash cấp 7) trên Redis để giảm 60% chi phí gọi Google/Goong API.
   - **Snap-to-Road**: Tự động nắn tọa độ GPS của tài xế vào tim đường thực tế để hiển thị xe chạy mượt mà trên app của khách.

3. **Hoàn thiện luồng Điều phối & Khớp lệnh (Dispatch & Matching)**:
   - **Cascade Dispatching**: Bắn thông báo nhận đơn tới tài xế điểm cao nhất (khoảng cách + rating + tỉ lệ nhận cuốc). Nếu sau 15s từ chối/không phản hồi -> chuyển tiếp tới tài xế thứ 2.
   - **Distributed Lock (Redis Redlock)**: Chống Race Condition khi 2 tài xế cùng bấm nhận 1 cuốc đồ ăn/đi chợ cùng lúc.
   - **Chuyển OTP in-memory sang Redis**: Dùng Redis Key `otp:{phone}` kèm TTL 300s và rate-limit 60s, kết nối SMS Brandname/Zalo ZNS thật.

---

### II. TÀI CHÍNH, THANH TOÁN & VÍ ĐIỆN TỬ (FINTECH & BILLING)

```
[Khách đặt xe] ──> Giữ tiền (Pre-auth / Hold)
                          │
[Hoàn thành cuốc] ──> Trừ tiền thật (Capture) ──> Xuất Hóa đơn điện tử (e-Invoice)
                          │
                  ┌───────┴────────┐
                  ▼                ▼
         Ví tài xế (+85%)     Doanh thu sàn (+15%)
                  │
                  ▼
         Tài xế bấm Rút tiền ──> Chi hộ 24/7 (Napas/VietQR)
```

1. **Pre-Authorization & Tokenization**: Với thẻ tín dụng/ví điện tử (MoMo/ZaloPay/VNPay/Visa), khi khách bấm đặt xe, hệ thống phải **Hold (tạm giữ hạn mức)** tiền cước ước tính. Khi tài xế bấm kết thúc cuốc mới tiến hành **Capture (trừ thật)** dựa trên quãng đường thực tế.
2. **Cơ chế Thu phí chiết khấu (Commission Deduction)**:
   - Nếu khách trả tiền mặt: Hệ thống trừ tiền hoa hồng (ví dụ 15% - 20%) trực tiếp vào `wallets` của tài xế. Nếu ví tài xế dưới 50.000 VNĐ, tự động tắt trạng thái Online nhận cuốc.
3. **Cổng Rút tiền tự động (Payout API 24/7)**:
   - Tích hợp Napas 247 / VietQR Chi hộ (qua PayOS, SePay Business, hoặc Baokim) để tài xế có thể rút tiền về tài khoản ngân hàng cá nhân mọi lúc.
4. **Hóa đơn điện tử tự động (e-Invoice)**:
   - Tuân thủ Thông tư 78/2021/TT-BTC & Nghị định 123/2020/NĐ-CP: Kết nối API xuất hóa đơn điện tử tự động (MISA meInvoice, VNPT Invoice hoặc Viettel S-Invoice) sau mỗi chuyến đi.

---

### III. BẢO MẬT & CHỐNG GIAN LẬN (SECURITY & ANTI-FRAUD)

1. **Chống Fake GPS (GPS Spoofing)**:
   - Trên Driver App: Kiểm tra flag `isFromMockProvider()` trên Android và `isSimulated` trên iOS.
   - Trên Backend: Phân tích gia tốc và vận tốc bất thường (ví dụ: vị trí nhảy cóc 2km trong 3 giây hoặc tốc độ xe máy > 130km/h trong hẻm) -> Tự động gắn cờ tài khoản để đối soát.
2. **Chống Tự đặt xe bào khuyến mãi (Collusion / Self-booking)**:
   - Chặn nhận cuốc nếu thiết bị khách và tài xế dùng chung IP WiFi, chung tài khoản ngân hàng nạp tiền, hoặc GPS của 2 máy ở cùng 1 điểm trước khi cuốc xe bắt đầu.
3. **Che số điện thoại (Masked Call / Number Privacy)**:
   - Tích hợp VoIP Call (Stringee / Twilio) cho phép khách và tài xế gọi điện cho nhau miễn phí trong app mà không để lộ số điện thoại cá nhân (chống quấy rối, rò rỉ thông tin).

---

### IV. PHÁP LÝ & TUÂN THỦ TẠI THỊ TRƯỜNG VIỆT NAM (COMPLIANCE)

1. **Nghị định 10/2020/NĐ-CP & Nghị định 47/2022/NĐ-CP (Kinh doanh vận tải)**:
   - Mô hình xe ôm công nghệ / taxi công nghệ yêu cầu kết nối dữ liệu hành trình về Cục Đường bộ Việt Nam.
   - Tài xế ô tô phải có phù hiệu xe hợp đồng, lắp thiết bị định vị (hộp đen) và camera giám sát người lái.
2. **Đăng ký Sàn Giao dịch Thương mại Điện tử (Bộ Công Thương)**:
   - Đăng ký website và ứng dụng Super App với Cục TMĐT & Kinh tế số (Bộ Công Thương) theo Nghị định 52/2013/NĐ-CP và Nghị định 85/2021/NĐ-CP để nhận logo xanh/đỏ "Đã đăng ký".
3. **Nghị định 13/2023/NĐ-CP (Bảo vệ dữ liệu cá nhân - PDPD)**:
   - Xây dựng bản Thỏa thuận xử lý dữ liệu cá nhân (DPA), quy trình xóa dữ liệu người dùng khi được yêu cầu, lập hồ sơ Đánh giá tác động xử lý dữ liệu cá nhân (DPIA) gửi Cục An ninh mạng (A05) Bộ Công An.
4. **Quy trình thẩm định tài xế (Driver Onboarding eKYC)**:
   - Bắt buộc kiểm tra CCCD gắn chip (NFC/OCR), giấy phép lái xe (GPLX), giấy đăng ký xe, bảo hiểm bắt buộc TNDS còn hạn và Lý lịch tư pháp số 2 (xác nhận không có tiền án).

---

### V. HẠ TẦNG CLOUD & VẬN HÀNH (DEVOPS & OPERATIONS)

1. **Hạ tầng Production**:
   - Chuyển dịch từ `docker-compose` đơn lẻ sang Kubernetes (AWS EKS, GCP GKE hoặc Viettel IDC / Bizfly Cloud) với cơ chế tự động co giãn (Horizontal Pod Autoscaler - HPA).
2. **Giám sát & Cảnh báo (Observability)**:
   - Logging tập trung: Promtail + Loki + Grafana.
   - APM & Tracing: OpenTelemetry + Jaeger (truy vết request qua các gRPC microservices).
   - Crash Reporting: Tích hợp Sentry vào Flutter app để bắt crash runtime.
3. **Tổng đài & Trung tâm Điều hành (Ops Center)**:
   - Nút **SOS** trên app khách và tài xế: Khi bấm phải tự động gửi SMS + GPS về trung tâm khẩn cấp và gọi tự động tới hotline an toàn.
   - Đội ngũ CSKH xử lý ticket khiếu nại (quên đồ trên xe, tài xế thái độ xấu, sai giá tiền).

---

## 📅 4. LỘ TRÌNH THỰC HIỆN 3 GIAI ĐOẠN (ROADMAP)

### 🔹 Giai đoạn 1: Ổn định lõi kỹ thuật & Tích hợp dịch vụ thật (4 – 6 tuần)
- Thay thế Haversine bằng API Routing thật (Goong Maps / OSRM).
- Hoàn thiện kết nối gRPC/MQTT giữa `matching-service`, `location-service` và `driver-service`.
- Chuyển OTP sang Redis và kết nối dịch vụ SMS/ZNS thật.
- Bổ sung ghi log tọa độ thực tế chuyến đi (`trip-service` breadcrumbs).

### 🔹 Giai đoạn 2: Thanh toán, Bảo mật & Tách App Tài xế (6 – 8 tuần)
- Hoàn thiện cổng thanh toán: MoMo/VNPay/ZaloPay và luồng Pre-auth/Capture.
- Xây dựng hệ thống Ví tài xế (Nạp/Rút Napas 247 tự động, khấu trừ hoa hồng).
- Tách `Driver App` thành project riêng, tối ưu hóa Background Location và Floating Widget.
- Tích hợp phát hiện Mock GPS và VoIP che số điện thoại (Stringee).

### 🔹 Giai đoạn 3: Pháp lý, Hệ thống Điều hành & Chạy thử nghiệm Pilot (4 – 6 tuần)
- Phát triển Admin Portal chuyên nghiệp (Quản trị tài xế, đối soát tài chính, can thiệp cuốc xe).
- Hoàn thiện hồ sơ pháp lý: Đăng ký Bộ Công Thương, tuân thủ Nghị định 10 và PDPD 13.
- Kết nối xuất hóa đơn điện tử tự động (MISA/VNPT).
- Triển khai Pilot tại 1 khu vực nhỏ (ví dụ: Quận 1 / Bình Thạnh hoặc 1 khu đô thị cụ thể) với 20 - 50 tài xế thử nghiệm trước khi mở rộng toàn thành phố.

---

## ❓ 5. CÂU HỎI MỞ CẦN LÀM RÕ (UNRESOLVED QUESTIONS)

1. **Phạm vi dịch vụ khi ra mắt**: Bạn dự định thương mại hóa đồng loạt cả 4 dịch vụ (*Chở khách, Đồ ăn, Đi chợ, Lái xe hộ*) ngay từ đầu, hay sẽ chọn 1 dịch vụ mũi nhọn (ví dụ: *Lái xe hộ* hoặc *Chở khách*) để kiểm chứng thị trường trước?
2. **Khu vực và hạ tầng Cloud**: Bạn sẽ đặt server tại Cloud quốc tế (AWS Singapore / GCP) hay Cloud nội địa Việt Nam (Viettel Cloud, VNPT, Bizfly) để đáp ứng quy định lưu trữ dữ liệu người dùng trong nước?
3. **Đối tác cổng thanh toán & SMS**: Bạn đã có pháp nhân doanh nghiệp để ký hợp đồng với các cổng thanh toán (VNPay, MoMo, PayOS) và nhà mạng viễn thông (SMS Brandname) chưa?

