---
name: Food Delivery Service
description: Hướng dẫn triển khai chức năng đặt đồ ăn - quản lý nhà hàng, menu, đơn hàng, tính giá, và giao hàng 3 bên (Khách - Quán - Tài xế).
---

# Food Delivery Service Architecture & Guide

## 1. Khi nào dùng skill này?
- Triển khai, debug hoặc tối ưu hóa chức năng giao đồ ăn (**Food Delivery**).
- Quản lý Quán ăn (`merchants`), Danh mục thực đơn và Món ăn (`menu_items`).
- Điều phối luồng đơn hàng 3 bên phức tạp: **Khách hàng** ↔ **Quán ăn** ↔ **Tài xế giao hàng**.
- Tính toán cước phí, chiết khấu hoa hồng quán (Commission 15-25%), phí đóng gói và cước vận chuyển.
- Tích hợp bảo mật chống gian lận trong giao nhận đồ ăn (chống bùng đơn, xác thực OTP nhận món).

---

## 2. Kiến Trúc Luồng 3 Bên & Máy Trạng Thái (State Machine)

Khác với dịch vụ chở khách (điểm đón là vị trí khách), giao đồ ăn có điểm lấy hàng là **Địa chỉ Quán ăn**.

```
Khách chọn món & Đặt hàng (orders: 'created')
         │
         ▼
Quán xác nhận đơn & Bắt đầu chuẩn bị ('merchant_confirmed' ──▶ 'preparing')
         │
         │  (Hệ thống trì hoãn 5-10 phút tùy món trước khi gọi tài xế)
         ▼
Hệ thống quét Tài xế gần Quán (PostGIS ST_DWithin <= 3km quanh Merchant)
         │
         ▼
Tài xế nhận đơn ('accepted') ──▶ Đến quán ('at_merchant')
         │
         ▼
Lấy món & Đối chiếu mã đơn ──▶ Bắt đầu giao ('in_progress')
         │
         ▼
Giao hàng thành công (Nhập OTP khách cung cấp) ──▶ Hoàn tất ('completed')
```

### Chi tiết trạng thái đơn hàng (`orders.status`):
| Trạng thái | Mô tả | Ai kích hoạt |
|---|---|---|
| `created` | Khách tạo giỏ hàng và gửi đặt hàng | Khách hàng |
| `merchant_confirmed` | Quán bấm nhận đơn trên Merchant App/Web | Quán ăn |
| `preparing` | Bếp đang nấu món (ETA chuẩn bị: 15-25 phút) | Quán ăn |
| `driver_assigned` | Tài xế đồng ý nhận đơn giao | Tài xế |
| `at_merchant` | Tài xế đã có mặt tại quán (GPS check <= 100m) | Tài xế |
| `picked_up` / `in_progress` | Tài xế nhận đủ túi đồ ăn, bắt đầu đi giao | Tài xế |
| `completed` | Khách nhận đồ ăn, xác thực OTP giao hàng | Tài xế + Khách |
| `cancelled` | Hủy đơn (Quán hết món hoặc không tìm thấy tài xế) | Quán / Hệ thống |

---

## 3. Mô Hình Dữ Liệu PostgreSQL & PostGIS

### 3.1. Bảng `merchants`
```sql
CREATE TABLE merchants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL, -- 'Cơm tấm', 'Trà sữa', 'Phở', 'Bún chả'
    phone VARCHAR(20),
    location GEOGRAPHY(POINT, 4326) NOT NULL, -- Tọa độ GPS quán
    address TEXT NOT NULL,
    logo_url TEXT,
    cover_url TEXT,
    rating NUMERIC(2,1) DEFAULT 5.0,
    total_orders INT DEFAULT 0,
    commission_rate NUMERIC(4,2) DEFAULT 0.20, -- 20% chiết khấu sàn
    prep_time_minutes INT DEFAULT 15,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_merchants_location ON merchants USING GIST (location);
```

### 3.2. Bảng `menu_items`
```sql
CREATE TABLE menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    category_name VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL,
    image_url TEXT,
    options JSONB DEFAULT '[]', -- Size: M/L, Topping: Trân châu, Đường, Đá
    is_available BOOLEAN DEFAULT true,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.3. Bảng `orders` & `order_items`
```sql
-- Đơn hàng food_delivery
INSERT INTO orders (
    idempotency_key, service_type, customer_id, merchant_id,
    pickup_location, pickup_address, dropoff_location, dropoff_address,
    status, fare_estimate, delivery_fee, packing_fee, payment_method
) VALUES (...);
```

---

## 4. Công Thức Tính Cước & Phân Chia Doanh Thu (Financial Model)

```
1. Tổng tiền món (Food Subtotal):
   Subtotal = Sum(item.price × item.quantity + options.price)

2. Phí đóng gói (Packaging Fee):
   PackagingFee = 2,000đ - 5,000đ / hộp (quán cấu hình)

3. Cước giao hàng (Delivery Fee):
   DeliveryFee = BaseRate (18,000đ cho 2km đầu) + (DistanceKm - 2) × 5,000đ/km

4. Tổng tiền khách trả:
   TotalCustomerPaid = Subtotal + PackagingFee + DeliveryFee - DiscountVoucher

5. Phân chia doanh thu (Revenue Split):
   - Quán nhận: Subtotal × (1 - commission_rate) + PackagingFee
   - Sàn thu hoa hồng: Subtotal × commission_rate
   - Tài xế nhận: DeliveryFee × 0.85 + DriverTip
```

---

## 5. Rào Chắn An Ninh & Chống Gian Lận (Anti-Fraud & Security)

### 5.1. Geofence Điểm Đến Của Tài Xế (Arrival Geofencing)
Ngăn chặn tài xế bấm "Đã tới quán" khi còn ở xa nhằm ép hủy đơn hoặc gian lận thời gian chờ:
```go
func ValidateDriverAtMerchant(driverLat, driverLng, merchantLat, merchantLng float64) bool {
    distMeters := HaversineDistanceMeters(driverLat, driverLng, merchantLat, merchantLng)
    return distMeters <= 150.0 // Bán kính tối đa 150m
}
```

### 5.2. Mã Xác Nhận OTP Giao Hàng (Delivery PIN Verification)
- Khi đơn hàng chuyển sang `in_progress`, hệ thống sinh mã ngẫu nhiên gồm 4 chữ số gửi lên màn hình khách hàng: `OTP = rand(1000, 9999)`.
- Tài xế khi đưa đồ cho khách phải hỏi mã này và nhập vào ứng dụng để kết thúc đơn (`completed`).
- Ngăn chặn tài xế bấm "Đã giao" mà không giao hàng hoặc giao nhầm người nhận.

### 5.3. Chống Bùng Đơn & Đơn Ảo (Phantom Orders Protection)
- Khách mới (tài khoản tạo < 48 giờ) đặt đơn COD > 300,000đ phải xác thực qua SMS OTP.
- Tài khoản có tỷ lệ hủy đơn COD > 30% trong 7 ngày gần nhất sẽ bị tạm khóa phương thức thanh toán tiền mặt (bắt buộc trả trước qua Ví/MoMo/VNPay).

---

## 6. Liên Kết Code & UI Trong Dự Án
- **API Gateway**:
  - [`services/api-gateway/internal/handler/merchant_handler.go`](../../services/api-gateway/internal/handler/merchant_handler.go): Danh sách quán ăn, tìm kiếm quán theo cự ly PostGIS, lấy thực đơn.
  - [`services/api-gateway/internal/repository/postgres_repo.go`](../../services/api-gateway/internal/repository/postgres_repo.go): `ListNearbyMerchants`, `GetMerchantMenu`.
- **Flutter Client (`apps/rider`)**:
  - `lib/screens/food/restaurant_list_screen.dart`: Danh sách nhà hàng gần nhất với rating và cự ly.
  - `lib/screens/food/restaurant_detail_screen.dart`: Chi tiết món ăn, chọn giỏ hàng.
  - `lib/screens/food/checkout_screen.dart`: Xác nhận đặt món, áp mã giảm giá.
  - `lib/screens/food/order_tracking_screen.dart`: Theo dõi tiến độ chuẩn bị món và shipper giao hàng.
- **Dữ liệu thật**: [`migrations/seed_real_data.sql`](../../migrations/seed_real_data.sql) (5 quán ăn thật tại TP.HCM & 13 món ăn có hình ảnh).
