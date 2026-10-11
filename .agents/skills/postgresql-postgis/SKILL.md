---
name: PostgreSQL + PostGIS Spatial Engineering
description: Hướng dẫn sử dụng PostgreSQL với PostGIS extension cho lưu trữ dữ liệu không gian, tối ưu GiST index, spatial queries và transaction safety.
---

# PostgreSQL + PostGIS Spatial Engineering Guide

## 1. Khi nào dùng skill này?
- Thiết kế cơ sở dữ liệu quan hệ kết hợp dữ liệu không gian địa lý (**Geospatial Database**).
- Viết câu lệnh truy vấn không gian phức tạp (`ST_DWithin`, `ST_Distance`, `ST_MakePoint`, `ST_Contains`).
- Đánh chỉ mục không gian tối ưu (**GiST Indexing**) tránh quét toàn bảng (Full Table Scan).
- Quản lý Pool kết nối hiệu năng cao với `github.com/jackc/pgx/v5/pgxpool` trong Golang.
- Quản lý Transaction an toàn (`SELECT ... FOR UPDATE`, `REPEATABLE READ`) khi xử lý tiền ví và nhận đơn.

---

## 2. Thiết Lập & Chuẩn Tọa Độ (WGS 84 - SRID 4326)

Hệ thống Xebuonho sử dụng chuẩn quốc tế **WGS 84 (SRID 4326)**:
- Kiểu dữ liệu khuyên dùng: `GEOGRAPHY(POINT, 4326)` hoặc `GEOMETRY(POINT, 4326)`.
- **Quy tắc vàng về thứ tự tọa độ trong PostGIS**:
  ```sql
  -- LUÔN LÀ (Longitude/Kinh độ, Latitude/Vĩ độ)
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
  ```
  *(Nếu truyền nhược `ST_MakePoint(lat, lng)`, tọa độ sẽ bị văng ra vùng cực hoặc đại dương).*

---

## 3. Các Hàm Không Gian Trọng Tâm (Core PostGIS Functions)

### 3.1. Tìm kiếm trong bán kính R mét (`ST_DWithin`):
```sql
-- Tìm các quán ăn trong bán kính 5,000 mét (5km) từ vị trí khách:
SELECT id, name, address,
       ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) as distance_meters
FROM merchants
WHERE is_active = true
  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 5000)
ORDER BY distance_meters ASC
LIMIT 20;
```

### 3.2. Tìm K tài xế gần nhất bằng toán tử k-NN (`<->`):
```sql
-- Dùng toán tử khoảng cách chỉ mục (Index-driven Nearest Neighbor):
SELECT id, full_name, phone
FROM drivers
WHERE is_online = true
ORDER BY current_location <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geometry
LIMIT 5;
```

---

## 4. Tối Ưu Chỉ Mục Không Gian (GiST Spatial Indexing)

Không có GiST Index, PostgreSQL sẽ thực hiện **Sequential Scan** (quét tuần tự toàn bảng), làm CPU tăng vọt 100% khi bảng có > 10,000 dòng.

```sql
-- Chỉ mục vị trí Quán ăn / Siêu thị
CREATE INDEX IF NOT EXISTS idx_merchants_location ON merchants USING GIST (location);

-- Chỉ mục điểm đón và điểm trả của cuốc xe
CREATE INDEX IF NOT EXISTS idx_orders_pickup_location ON orders USING GIST (pickup_location);
CREATE INDEX IF NOT EXISTS idx_orders_dropoff_location ON orders USING GIST (dropoff_location);

-- Partial Composite Index phục vụ lọc cuốc xe chờ nhận
CREATE INDEX IF NOT EXISTS idx_orders_pending_matching 
ON orders (status, created_at DESC) 
WHERE status = 'created';
```

---

## 5. An Toàn Giao Dịch & Transaction Locking (Go + pgxpool)

Khi xử lý các hành động nhạy cảm (nhận cuốc xe, trừ tiền ví):

```go
package repository

import (
    "context"
    "fmt"
    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"
)

func DeductWalletAtomic(ctx context.Context, pool *pgxpool.Pool, userID string, amount float64) error {
    tx, err := pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.ReadCommitted})
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    // Khóa dòng ví (Pessimistic Lock)
    var currentBalance float64
    err = tx.QueryRow(ctx, "SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE", userID).Scan(&currentBalance)
    if err != nil {
        return fmt.Errorf("wallet not found: %w", err)
    }

    if currentBalance < amount {
        return fmt.Errorf("insufficient balance (have: %.0f, need: %.0f)", currentBalance, amount)
    }

    // Trừ tiền
    _, err = tx.Exec(ctx, "UPDATE wallets SET balance = balance - $1, updated_at = NOW() WHERE user_id = $2", amount, userID)
    if err != nil {
        return err
    }

    return tx.Commit(ctx)
}
```

---

## 6. Seed Dữ Liệu Thật & Chạy Migrations
- Script nạp dữ liệu: [`migrations/seed_real_data.sql`](../../migrations/seed_real_data.sql)
- Lệnh nạp qua Docker:
  ```bash
  docker exec -i xebuonho-postgres psql -U postgres -d xebuonho < migrations/seed_real_data.sql
  ```
- Xem thêm tài liệu chi tiết: [`skills/real-data-postgresql/SKILL.md`](../real-data-postgresql/SKILL.md)

---

## 7. References
- Schema chi tiết: [`docs/architecture/DATA-LAYER.md`](../../docs/architecture/DATA-LAYER.md)
- Repository Golang: [`services/api-gateway/internal/repository/postgres_repo.go`](../../services/api-gateway/internal/repository/postgres_repo.go)
- Skill Real Data: [`skills/real-data-postgresql/SKILL.md`](../real-data-postgresql/SKILL.md)
- Skill Security: [`skills/security-anti-fraud/SKILL.md`](../security-anti-fraud/SKILL.md)
