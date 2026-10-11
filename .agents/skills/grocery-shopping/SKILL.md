---
name: Grocery Shopping Service
description: Hướng dẫn triển khai chức năng đi chợ hộ - shopping list, product substitution, receipt upload, và rào chắn an ninh tài chính.
---

# Grocery Shopping Service Architecture & Implementation Guide

## 1. Khi nào dùng skill này?
- Triển khai, bảo trì hoặc mở rộng dịch vụ **Đi Chợ Hộ (Grocery Shopping)**.
- Quản lý danh sách mặt hàng cần mua (`shopping_list`), đơn vị tính (kg, bó, vỉ, chai).
- Xử lý tương tác thời gian thực khi hết hàng hoặc thay thế sản phẩm (**Product Substitution Flow**).
- Quy trình chụp ảnh, tải lên và xác minh hóa đơn mua hàng thực tế (**Receipt Verification**).
- Quản lý hạn mức ứng tiền của tài xế và tạm giữ số dư khách hàng (**Pre-authorization Escrow**).

---

## 2. Kiến Trúc Luồng Đi Chợ & Máy Trạng Thái (State Machine)

Khác với giao hàng thông thường, tài xế trong dịch vụ đi chợ hộ kiêm 2 vai trò: **Người mua sắm trực tiếp** (Personal Shopper) và **Tài xế giao hàng** (Delivery Driver).

```
[Khách hàng]
Tạo danh sách đồ cần mua + Chọn siêu thị/chợ
         │
         ▼
Hệ thống ước tính cước & Tạm giữ tiền ví/thẻ (Pre-auth Escrow: Giá ước tính × 1.25)
         │
         ▼
[Tài xế nhận đơn] (Driver check: ví tài xế có đủ hạn mức ứng tiền)
         │
         ▼
Tài xế đến chợ / siêu thị ('at_store' - Geofence check <= 200m)
         │
         ▼
Mua sắm ('shopping') ◀─── Hết hàng? Đề xuất món thay thế ───▶ Khách duyệt qua Chat
         │
         ▼
Mua sắm hoàn tất ('shopping_done')
         │
         ▼
Chụp ảnh & Upload hóa đơn ('receipt_uploaded' - Nhập tiền thực tế)
         │
         ▼
Hệ thống chốt giá & Cấn trừ tiền chính xác
         │
         ▼
Giao hàng ('delivering') ──▶ Giao thành công ('delivered') ──▶ Thanh toán ('completed')
```

---

## 3. Cấu Trúc Dữ Liệu & Danh Sách Mua Sắm (Data Models)

### 3.1. Cấu trúc `shopping_list` (Lưu dưới dạng JSONB trong `orders.items_detail`):
```json
[
  {
    "item_id": "item-01",
    "name": "Thịt ba chỉ bò Úc",
    "quantity": 0.5,
    "unit": "kg",
    "estimated_price": 125000,
    "notes": "Chọn khay date mới nhất",
    "status": "purchased", // pending, purchased, substituted, out_of_stock
    "actual_price": 128000
  },
  {
    "item_id": "item-02",
    "name": "Rau muống baby",
    "quantity": 2,
    "unit": "bó",
    "estimated_price": 20000,
    "notes": "Không lấy lá úa",
    "status": "substituted",
    "substituted_item": {
      "name": "Rau mồng tơi",
      "price": 22000,
      "approved_by_customer": true
    }
  }
]
```

### 3.2. Cột mở rộng trên bảng `orders`
```sql
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS grocery_store_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS grocery_estimated_cost NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grocery_actual_cost NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grocery_service_fee NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS receipt_image_url TEXT,
ADD COLUMN IF NOT EXISTS receipt_hash VARCHAR(64);
```

---

## 4. Công Thức Tính Phí & Hạn Mức Ứng Tiền

```
1. Tiền hàng thực tế (Actual Goods Cost):
   Lấy từ ảnh hóa đơn mua hàng do tài xế nhập và chụp ảnh đối chiếu.

2. Phí công mua hộ (Shopper Service Fee):
   ServiceFee = Max(20,000đ, ActualGoodsCost × 15%)

3. Phí giao hàng (Delivery Fee):
   DeliveryFee = 18,000đ (2km đầu) + (DistanceKm - 2) × 5,000đ/km

4. Tổng tiền khách hàng thanh toán:
   Total = ActualGoodsCost + ServiceFee + DeliveryFee - PromoDiscount

5. Hạn mức tài xế ứng trước (Driver Advance Cap):
   - Mặc định tối đa: 1,000,000 VNĐ / đơn hàng.
   - Tài xế mới (< 30 ngày): tối đa 500,000 VNĐ.
   - Các đơn hàng giá trị > 1,000,000 VNĐ bắt buộc khách hàng thanh toán trực tuyến 100% trước khi điều phối tài xế.
```

---

## 5. Rào Chắn An Ninh & Phòng Ngừa Gian Lận (Anti-Fraud)

### 5.1. Giới Hạn Biên Độ Chênh Lệch Giá (Price Cap Guardrail)
Để ngăn chặn tài xế cấu kết nâng khống tiền hóa đơn:
```go
const MaxPriceDeviationMultiplier = 1.30 // Cho phép vượt tối đa 30%

func ValidateReceiptCost(estimated, actual float64) error {
    maxAllowed := estimated * MaxPriceDeviationMultiplier
    if actual > maxAllowed {
        return fmt.Errorf("tiền thực tế (%.0f) vượt quá 30%% dự tính (%.0f). Yêu cầu duyệt đặc biệt", actual, maxAllowed)
    }
    return nil
}
```

### 5.2. Chống Gian Lận Ảnh Hóa Đơn Trùng Lặp (Duplicate Receipt Detection)
- Khi tài xế upload ảnh hóa đơn, hệ thống tính hash MD5 / pHash (Perceptual Hash) của ảnh.
- Nếu ảnh hóa đơn này đã từng được dùng cho một đơn hàng khác trong 30 ngày qua, hệ thống lập tức tạm giữ đơn hàng và kích hoạt cờ kiểm tra gian lận (`fraud_flag = 'DUPLICATE_RECEIPT'`).

### 5.3. Geofence Điểm Mua Hàng (Store Geofencing)
Tài xế chỉ có thể chuyển trạng thái sang `shopping` khi vị trí GPS hiện tại cách chợ hoặc siêu thị đã chỉ định không quá **200 mét** (`ST_DWithin`).

---

## 6. Giao Diện & Điều Hướng Trong Dự Án (Flutter Client)
- **Màn hình đặt đồ đi chợ**:
  [`apps/rider/lib/screens/grocery/grocery_order_screen.dart`](../../apps/rider/lib/screens/grocery/grocery_order_screen.dart): Tạo danh sách đồ, chọn đơn vị, ước tính chi phí và siêu thị gần nhất.
- **Màn hình theo dõi & xác nhận đổi món**:
  [`apps/rider/lib/screens/grocery/grocery_tracking_screen.dart`](../../apps/rider/lib/screens/grocery/grocery_tracking_screen.dart): Trực quan hóa tiến độ mua sắm theo thời gian thực (Đang mua -> Đổi món -> Chụp bill -> Đang giao).
- **Backend API**:
  - `POST /api/v1/rides` với `service_type: 'grocery'`
  - WebSocket hub thông báo trạng thái đơn hàng và tin nhắn chat trao đổi ảnh món ăn.
