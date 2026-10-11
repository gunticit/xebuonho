---
name: Designated Driver Service
description: Hướng dẫn triển khai chức năng lái xe hộ - vehicle inspection, shadow driver (solo/duo), night surcharge, và quy chuẩn an toàn pháp lý.
---

# Designated Driver Service Architecture & Guide

## 1. Khi nào dùng skill này?
- Triển khai, kiểm thử hoặc mở rộng dịch vụ **Lái Xe Hộ (Designated Driver)** khi chủ phương tiện đã uống rượu bia hoặc mệt mỏi.
- Quản lý quy trình kiểm tra xe nghiêm ngặt trước và sau chuyến đi (**Vehicle Inspection Checklist**).
- Điều phối hai mô hình đưa đón tài xế: **Solo** (Xe đạp điện gấp trong cốp) và **Duo** (Tài xế phụ chạy xe máy theo sau).
- Tính cước phụ thu đêm khuya (22h - 6h sáng: +30%) và phí đưa đón tài xế.
- Xử lý pháp lý, bảo hiểm trách nhiệm dân sự và hợp đồng dịch vụ ủy quyền lái xe tạm thời.

---

## 2. Mô Hình Điều Phối & Shadow Driver Modes

Khách hàng giao chìa khóa phương tiện cá nhân của mình (ô tô hoặc xe máy) cho tài xế của hệ thống cầm lái đưa cả khách và xe về nhà.

```
                    ┌────────────────────────────────────────┐
                    │      Khách đặt Lái Xe Hộ Ô Tô/Xe Máy   │
                    └───────────────────┬────────────────────┘
                                        │
                         Chọn chế độ đưa đón tài xế
                       ┌────────────────┴────────────────┐
                       ▼                                 ▼
            [Chế độ Solo Driver]               [Chế độ Duo Driver]
         1 Tài xế ô tô có xe gấp          2 Tài xế cùng di chuyển:
         Cất xe gấp vào cốp xe khách      - Tài xế chính: Lái xe khách
         Đến nơi: Lấy xe gấp tự về        - Tài xế bóng (Shadow): Đi xe máy theo sau
                                          Đến nơi: Chở tài xế chính về
```

### So sánh hai chế độ:
| Tiêu chí | Solo Driver | Duo Driver (Khuyên dùng giờ cao điểm/đêm) |
|---|---|---|
| Số lượng nhân sự | 1 tài xế | 2 tài xế |
| Điều kiện phương tiện | Xe khách phải có cốp chứa được xe gấp | Mọi loại xe ô tô / xe tải nhỏ |
| Phụ thu phí di chuyển | 0đ | +40,000đ - 60,000đ (phí xe máy hỗ trợ) |
| Tốc độ di chuyển | Linh hoạt | Hai xe đi song song |

---

## 3. Máy Trạng Thái Đơn Hàng (State Machine)

```
CREATED (orders: 'created')
   │
   ▼
DRIVER_ASSIGNED (Hệ thống kiểm tra GPLX B2/C còn hiệu lực)
   │
   ▼
DRIVER_ARRIVING ──▶ ARRIVED (Tài xế gặp khách tại quán/nhà hàng)
   │
   ▼
VEHICLE_INSPECTION (BẮT BUỘC: Chụp 4 ảnh xe + Số km ODO + Mức xăng + Quay clip trầy xước)
   │
   ▼
IN_PROGRESS / DRIVING (Khách ngồi ghế phụ/sau, tài xế cầm lái)
   │
   ▼
ARRIVED_DESTINATION (Đến điểm đỗ xe của khách: bãi xe/hầm chung cư)
   │
   ▼
VEHICLE_HANDOVER (Kiểm tra lại xe + Ký xác nhận bàn giao chìa khóa)
   │
   ▼
COMPLETED ──▶ PAID (Chốt cước và cộng thưởng cho tài xế)
```

---

## 4. Biên Bản Kiểm Tra Xe Bắt Buộc (Vehicle Inspection Protocol)

Để triệt tiêu 100% rủi ro khiếu nại đền bù trầy xước xe có từ trước:

### 4.1. Bộ ảnh bằng chứng (4 góc + 2 nội thất):
1. **Ảnh 1**: Đầu xe và biển số trước.
2. **Ảnh 2**: Đuôi xe và biển số sau.
3. **Ảnh 3**: Sườn xe bên trái (gương, cửa, lazang).
4. **Ảnh 4**: Sườn xe bên phải (gương, cửa, lazang).
5. **Ảnh 5**: Bảng đồng hồ công-tơ-mét (ODO km) và kim xăng.
6. **Ảnh 6**: Tình trạng kính lái và camera hành trình xe (nếu có).

### 4.2. Watermark an ninh:
Mọi ảnh chụp từ ứng dụng Flutter BẮT BUỘC được đóng dấu chìm:
- Tọa độ GPS chụp (`lat, lng`).
- Dấu thời gian chính xác (`timestamp` từ NTP server, không lấy giờ điện thoại).
- Mã đơn hàng (`order_id`).

---

## 5. Công Thức Tính Cước (Pricing & Night Surcharge)

Cước lái xe hộ cao hơn cuốc xe thông thường vì yêu cầu kỹ năng lái nhiều loại xe (số sàn, số tự động, xe sang Đức):

```
BaseFare = 60,000 VNĐ (cho 2km đầu tiên)
RatePerKm = 16,000 VNĐ / km

1. Cước cơ sở:
   TripFare = BaseFare + (DistanceKm - 2) × RatePerKm

2. Phụ thu đêm khuya (Night Surcharge - 22:00 đến 06:00 sáng hôm sau):
   NightMultiplier = 1.30 (+30% tổng cước)

3. Phụ thu xe máy đi kèm (nếu chọn chế độ Duo):
   ShadowDriverFee = 45,000 VNĐ

4. Tổng chi phí:
   Total = (TripFare × NightMultiplier) + ShadowDriverFee - PromoDiscount
```

---

## 6. Điều Khoản Pháp Lý & Điều Kiện Tiếp Nhận
1. **Kiểm tra nồng độ cồn**: Tài xế tuyệt đối có nồng độ cồn = 0 (kiểm tra ngẫu nhiên bằng máy đo cồn tại trạm điều phối).
2. **Giấy tờ xe**: Khách hàng phải xác nhận phương tiện có đăng ký xe (Cà vẹt) và bảo hiểm TNDS hợp lệ.
3. **Tài sản cá nhân**: Khách hàng được hướng dẫn kiểm tra và cất giữ tư trang quý giá (tiền mặt, điện thoại, đồng hồ) trước khi bắt đầu hành trình.
4. **Cam kết trách nhiệm**: Nền tảng mua bảo hiểm trách nhiệm pháp lý trị giá lên tới 200,000,000đ cho mỗi chuyến lái xe hộ ô tô.

---

## 7. Giao Diện & Module Code Trong Dự Án
- **Giao diện Khách hàng (`apps/rider`)**:
  - [`lib/screens/designated/designated_driver_screen.dart`](../../apps/rider/lib/screens/designated/designated_driver_screen.dart): Chọn phương tiện của bạn (Ô tô số sàn/tự động, xe máy), chọn chế độ Solo/Duo, xem ước tính cước và phụ thu đêm.
  - [`lib/screens/designated/designated_tracking_screen.dart`](../../apps/rider/lib/screens/designated/designated_tracking_screen.dart): Theo dõi tài xế đến, xem biên bản kiểm tra 4 góc xe, theo dõi hành trình lái xe về nhà.
- **Backend API Gateway**:
  - `POST /api/v1/rides` với `service_type: 'designated_driver'`.
  - Hàm tính cước tự động kích hoạt phụ thu đêm +30% nếu thời gian tạo đơn từ 22h-6h sáng.
