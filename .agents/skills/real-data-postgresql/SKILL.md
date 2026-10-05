---
name: PostgreSQL & PostGIS Real Data Architecture
description: Hướng dẫn kết nối cơ sở dữ liệu thật PostgreSQL + PostGIS, mô hình dữ liệu, spatial queries, và luồng đơn hàng realtime.
---

# PostgreSQL & PostGIS Real Data Architecture

## 1. Khi nào dùng skill này?
- Làm việc với cơ sở dữ liệu thật của dự án (`xebuonho` trên PostgreSQL port 5432).
- Viết hoặc tối ưu các truy vấn không gian (Geospatial Spatial Queries: tìm tài xế gần nhất, tìm quán ăn gần nhất, tính cước theo khoảng cách).
- Mở rộng bảng `orders`, `merchants`, `menu_items`, `users`, hoặc `driver_capabilities`.
- Xử lý tính lũy tiến (idempotency), transaction an toàn và chống race-condition khi nhiều tài xế nhận cùng 1 cuốc xe.

---

## 2. Thông số kết nối & Cấu hình Database

- **Database URL**: `postgres://postgres:postgres@localhost:5432/xebuonho?sslmode=disable`
- **Driver**: `github.com/jackc/pgx/v5/pgxpool` (Go Connection Pool tối ưu hiệu năng cao)
- **Extension**: `CREATE EXTENSION IF NOT EXISTS postgis;`
- **Hệ tọa độ**: `WGS 84` (`SRID 4326`), kiểu dữ liệu `geography(POINT, 4326)` hoặc `geometry(POINT, 4326)`.
  - Lưu ý: trong PostGIS, thứ tự tham số luôn là `ST_MakePoint(Longitude, Latitude)`.

---

## 3. Các bảng dữ liệu cốt lõi (Core Tables)

### 3.1. `users` & `driver_capabilities`
- `users`: Quản lý thông tin tài khoản (Phone, Full Name, Password Hash, Role: `rider`, `driver`, `merchant`, `admin`).
- `driver_capabilities`: Khả năng cung cấp dịch vụ của tài xế:
  ```sql
  CREATE TABLE driver_capabilities (
      driver_id UUID NOT NULL REFERENCES users(id),
      service_type VARCHAR(50) NOT NULL, -- ride, food_delivery, grocery, designated_driver
      has_car_license BOOLEAN DEFAULT false,
      has_bike BOOLEAN DEFAULT false,
      PRIMARY KEY (driver_id, service_type)
  );
  ```
- `vehicles`: Thông tin phương tiện (`license_plate`, `brand`, `model`, `color`, `seat_capacity`).

### 3.2. `merchants` & `menu_items` (Quán ăn, Cửa hàng tiện lợi)
- Lưu tọa độ vị trí bằng PostGIS: `location GEOGRAPHY(POINT, 4326)`.
- `menu_items`: Sản phẩm và giá tiền, danh mục, hình ảnh minh họa thực tế.

### 3.3. `orders` (Bảng trung tâm của toàn bộ chuyến đi & đơn hàng)
- Trạng thái vòng đời:
  `created` -> `accepted` -> `arrived` -> `in_progress` -> `completed` (hoặc `cancelled`).
- Tọa độ: `pickup_location` và `dropoff_location` kiểu `GEOGRAPHY(POINT, 4326)`.
- Khóa chống trùng: `idempotency_key VARCHAR(255) UNIQUE`.

---

## 4. Các truy vấn Spatial mẫu trong Go (`PostgresRepo`)

File triển khai: [`services/api-gateway/internal/repository/postgres_repo.go`](file:///Users/hwg/Documents/xebuonho/services/api-gateway/internal/repository/postgres_repo.go)

### 4.1. Tìm quán ăn gần vị trí khách hàng trong bán kính R km:
```sql
SELECT id, name, description, category, address,
       ST_Y(location::geometry) as latitude,
       ST_X(location::geometry) as longitude,
       ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000.0 as distance_km
FROM merchants
WHERE is_active = true
  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
ORDER BY distance_km ASC LIMIT 20;
```

### 4.2. Chèn cuốc xe với PostGIS Point và Idempotency:
```sql
INSERT INTO orders (
    idempotency_key, service_type, customer_id,
    pickup_location, pickup_address, dropoff_location, dropoff_address,
    vehicle_type, status, fare_estimate, payment_method, promo_code,
    distance_km, duration_minutes
) VALUES (
    $1, 'ride', $2,
    ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5,
    ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography, $8,
    $9, 'created', $10, $11, $12, $13, $14
)
ON CONFLICT (idempotency_key) DO UPDATE SET updated_at = NOW()
RETURNING id, customer_id, pickup_address, dropoff_address, vehicle_type, status,
          fare_estimate, COALESCE(distance_km, 0), COALESCE(duration_minutes, 0), created_at;
```

### 4.3. Nhận cuốc xe an toàn chống race condition:
```sql
UPDATE orders
SET driver_id = $2, status = 'accepted', accepted_at = NOW(), updated_at = NOW()
WHERE id = $1 AND status = 'created';
```
*(Nếu `RowsAffected() == 0`, báo lỗi cuốc xe đã có tài xế khác nhận trước).*

---

## 5. Script Seed dữ liệu mẫu thực tế

File: [`migrations/seed_real_data.sql`](file:///Users/hwg/Documents/xebuonho/migrations/seed_real_data.sql)
Chạy nạp lại dữ liệu:
```bash
docker exec -i xebuonho-postgres psql -U postgres -d xebuonho < migrations/seed_real_data.sql
```
Dữ liệu mẫu gồm:
- 5 Quán ăn & Cửa hàng thực tế tại TP.HCM (Cơm Tấm Phúc Lộc Thọ, Phúc Long Coffee & Tea, Phở 24, Bún Chả 1982, WinMart+ Landmark 81).
- 13 Món ăn có đơn giá thật từ 25.000đ - 79.000đ.
- 2 Tài khoản Rider và Driver chuẩn để test end-to-end.
