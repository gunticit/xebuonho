# 💾 Database & Caching Layer

> Xử lý hàng vạn tọa độ mỗi giây mà không bị quá tải.

## Nguyên tắc chọn Database

```
┌────────────────────────────────────────────────────────────┐
│ "Dữ liệu nóng" → Redis (RAM)                              │
│  - Vị trí tài xế realtime                                  │
│  - Session, cache                                           │
│  - Tính toán geo (tìm tài xế gần)                          │
├────────────────────────────────────────────────────────────┤
│ "Dữ liệu lạnh" → PostgreSQL + PostGIS (Disk)              │
│  - Thông tin User, Driver                                   │
│  - Lịch sử chuyến đi                                       │
│  - Thanh toán, ví tiền                                      │
│  - Dữ liệu bản đồ tĩnh                                    │
└────────────────────────────────────────────────────────────┘
```

---

## 1. Redis - In-Memory Data Store

### Tại sao Redis là bắt buộc?

Nếu bạn lưu tọa độ thay đổi mỗi giây vào MySQL → **hệ thống sập ngay**. Redis lưu trên RAM, đọc/ghi trong **< 1ms**.

### Redis Geospatial (Redis GEO) - Tính năng then chốt

Redis GEO cho phép:
- Lưu tọa độ tài xế dưới dạng sorted set
- Tìm tài xế trong bán kính X km chỉ trong **~1ms**
- Tính khoảng cách giữa 2 điểm

```redis
# === LƯU VỊ TRÍ TÀI XẾ ===
# GEOADD key longitude latitude member
GEOADD active_drivers 106.6297 10.8231 "driver:abc123"
GEOADD active_drivers 106.6350 10.8200 "driver:def456"
GEOADD active_drivers 106.6280 10.8250 "driver:ghi789"

# === TÌM TÀI XẾ GẦN NHẤT ===
# GEORADIUS key longitude latitude radius unit [COUNT count] [ASC]
GEORADIUS active_drivers 106.6300 10.8220 2 km COUNT 5 ASC WITHDIST WITHCOORD
# Kết quả:
# 1) "driver:abc123" - 0.35 km - (106.6297, 10.8231)
# 2) "driver:ghi789" - 0.42 km - (106.6280, 10.8250)
# 3) "driver:def456" - 0.58 km - (106.6350, 10.8200)

# === TÍNH KHOẢNG CÁCH ===
GEODIST active_drivers "driver:abc123" "driver:def456" km
# Kết quả: "0.62"

# === LƯU METADATA TÀI XẾ ===
# Dùng Hash để lưu thông tin bổ sung
HSET driver:abc123:meta \
    status "online" \
    vehicle_type "car" \
    rating 4.8 \
    heading 45.0 \
    speed 30.5 \
    last_update 1709020800 \
    battery 85

# TTL để tự xóa tài xế offline (không cập nhật > 60s)
EXPIRE driver:abc123:meta 60
```

### Go Redis GEO Client

```go
package redis

import (
    "context"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
)

type LocationStore struct {
    client *redis.Client
}

const (
    activeDriversKey = "active_drivers"
    driverMetaPrefix = "driver:%s:meta"
    metaTTL          = 60 * time.Second
)

// UpdateDriverLocation cập nhật vị trí tài xế trên Redis GEO
func (s *LocationStore) UpdateDriverLocation(ctx context.Context, driverID string, lat, lng float64) error {
    pipe := s.client.Pipeline()
    
    // 1. Cập nhật GEO position
    pipe.GeoAdd(ctx, activeDriversKey, &redis.GeoLocation{
        Name:      fmt.Sprintf("driver:%s", driverID),
        Longitude: lng,
        Latitude:  lat,
    })
    
    // 2. Cập nhật metadata + reset TTL
    metaKey := fmt.Sprintf(driverMetaPrefix, driverID)
    pipe.HSet(ctx, metaKey, "last_update", time.Now().Unix())
    pipe.Expire(ctx, metaKey, metaTTL)
    
    _, err := pipe.Exec(ctx)
    return err
}

// FindNearbyDrivers tìm tài xế trong bán kính radius (km)
func (s *LocationStore) FindNearbyDrivers(
    ctx context.Context,
    lat, lng, radiusKm float64,
    maxCount int,
) ([]NearbyDriver, error) {
    results, err := s.client.GeoSearch(ctx, activeDriversKey, &redis.GeoSearchQuery{
        Longitude:  lng,
        Latitude:   lat,
        Radius:     radiusKm,
        RadiusUnit: "km",
        Count:      maxCount,
        Sort:       "ASC", // Gần nhất trước
    }).Result()
    if err != nil {
        return nil, err
    }
    
    drivers := make([]NearbyDriver, 0, len(results))
    for _, r := range results {
        // Lấy metadata
        metaKey := fmt.Sprintf(driverMetaPrefix, r.Name[7:]) // remove "driver:" prefix
        meta, _ := s.client.HGetAll(ctx, metaKey).Result()
        
        drivers = append(drivers, NearbyDriver{
            DriverID:    r.Name[7:],
            Latitude:    r.Latitude,
            Longitude:   r.Longitude,
            DistanceKm:  r.Dist,
            VehicleType: meta["vehicle_type"],
            Rating:      parseFloat(meta["rating"]),
        })
    }
    
    return drivers, nil
}

// RemoveDriver xóa tài xế khỏi pool active
func (s *LocationStore) RemoveDriver(ctx context.Context, driverID string) error {
    pipe := s.client.Pipeline()
    pipe.ZRem(ctx, activeDriversKey, fmt.Sprintf("driver:%s", driverID))
    pipe.Del(ctx, fmt.Sprintf(driverMetaPrefix, driverID))
    _, err := pipe.Exec(ctx)
    return err
}
```

### Redis Cluster Architecture

```
┌──────────────────────────────────────────────┐
│              Redis Cluster (6 nodes)          │
├──────────────────────────────────────────────┤
│                                               │
│  Master 1 ──── Replica 1   (Slots 0-5460)    │
│  Master 2 ──── Replica 2   (Slots 5461-10922)│
│  Master 3 ──── Replica 3   (Slots 10923-16383)│
│                                               │
│  ✅ Auto-failover khi Master down             │
│  ✅ Horizontal scaling                        │
│  ✅ Data partitioning                         │
└──────────────────────────────────────────────┘
```

---

## 2. PostgreSQL + PostGIS

### Tại sao PostgreSQL?

- **ACID compliance**: Không bao giờ sai lệch tiền bạc
- **PostGIS extension**: Xử lý dữ liệu không gian mạnh nhất thế giới
- **Mature ecosystem**: Replication, partitioning, monitoring tools

### Database Schema

```sql
-- ==========================================
-- USERS & AUTHENTICATION
-- ==========================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone           VARCHAR(15) UNIQUE NOT NULL,
    email           VARCHAR(255),
    full_name       VARCHAR(100) NOT NULL,
    avatar_url      TEXT,
    role            VARCHAR(10) NOT NULL CHECK (role IN ('rider', 'driver', 'admin')),
    status          VARCHAR(20) DEFAULT 'active',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);

-- ==========================================
-- DRIVERS
-- ==========================================
CREATE TABLE drivers (
    id              UUID PRIMARY KEY REFERENCES users(id),
    license_plate   VARCHAR(20) NOT NULL,
    vehicle_type    VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('bike', 'car', 'premium', 'suv')),
    vehicle_model   VARCHAR(100),
    vehicle_color   VARCHAR(30),
    rating          DECIMAL(3,2) DEFAULT 5.00,
    total_trips     INTEGER DEFAULT 0,
    is_verified     BOOLEAN DEFAULT FALSE,
    documents_url   JSONB,          -- CMND, GPLX, Đăng ký xe
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- RIDES (Cuốc xe)
-- ==========================================
CREATE TABLE rides (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key VARCHAR(64) UNIQUE NOT NULL, -- ← CHỐNG DUPLICATE
    rider_id        UUID NOT NULL REFERENCES users(id),
    driver_id       UUID REFERENCES users(id),
    
    -- Locations (PostGIS)
    pickup_location GEOGRAPHY(POINT, 4326) NOT NULL,
    pickup_address  TEXT NOT NULL,
    dropoff_location GEOGRAPHY(POINT, 4326) NOT NULL,
    dropoff_address TEXT NOT NULL,
    
    -- Trip details
    vehicle_type    VARCHAR(20) NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'searching',
    distance_km     DECIMAL(10,2),
    duration_minutes INTEGER,
    
    -- Pricing
    fare_estimate   DECIMAL(12,0) NOT NULL,  -- VND
    fare_final      DECIMAL(12,0),
    surge_multiplier DECIMAL(3,2) DEFAULT 1.00,
    promo_code      VARCHAR(20),
    discount_amount DECIMAL(12,0) DEFAULT 0,
    
    -- Timestamps
    requested_at    TIMESTAMPTZ DEFAULT NOW(),
    accepted_at     TIMESTAMPTZ,
    picked_up_at    TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    cancelled_by    VARCHAR(10), -- 'rider' or 'driver'
    cancel_reason   TEXT,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    -- State machine constraint
    CONSTRAINT valid_status CHECK (status IN (
        'searching', 'driver_assigned', 'driver_arriving',
        'arrived', 'in_progress', 'completed', 'cancelled', 'paid'
    ))
);

-- PostGIS spatial indexes
CREATE INDEX idx_rides_pickup ON rides USING GIST(pickup_location);
CREATE INDEX idx_rides_dropoff ON rides USING GIST(dropoff_location);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_rider ON rides(rider_id, created_at DESC);
CREATE INDEX idx_rides_driver ON rides(driver_id, created_at DESC);
CREATE INDEX idx_rides_idempotency ON rides(idempotency_key);

-- ==========================================
-- PAYMENTS
-- ==========================================
CREATE TABLE payments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id         UUID NOT NULL REFERENCES rides(id),
    rider_id        UUID NOT NULL REFERENCES users(id),
    amount          DECIMAL(12,0) NOT NULL,
    method          VARCHAR(20) NOT NULL CHECK (method IN ('cash', 'wallet', 'card', 'momo', 'zalopay')),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending',
    transaction_id  VARCHAR(100),
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- TRIP HISTORY & RATINGS
-- ==========================================
CREATE TABLE ratings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id         UUID UNIQUE NOT NULL REFERENCES rides(id),
    rider_rating    SMALLINT CHECK (rider_rating BETWEEN 1 AND 5),
    driver_rating   SMALLINT CHECK (driver_rating BETWEEN 1 AND 5),
    rider_comment   TEXT,
    driver_comment  TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- PostGIS QUERIES EXAMPLES
-- ==========================================

-- Tìm tất cả chuyến xe trong khu vực
-- (dùng cho admin dashboard, analytics)
SELECT id, rider_id, pickup_address,
       ST_Distance(pickup_location, ST_MakePoint(106.63, 10.82)::geography) AS distance_m
FROM rides
WHERE ST_DWithin(
    pickup_location,
    ST_MakePoint(106.63, 10.82)::geography,
    5000  -- 5km radius
)
AND status = 'completed'
AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY distance_m;
```

### Connection Pooling (PgBouncer)

```
┌─────────────────────────────────────────────┐
│  Go Services (hundreds of connections)       │
│     ↓          ↓          ↓                 │
│  ┌──────────────────────────────────┐       │
│  │  PgBouncer (Connection Pooler)    │       │
│  │  - Transaction pooling mode       │       │
│  │  - Max 20 connections to PG       │       │
│  │  - Handles 1000+ service conns    │       │
│  └──────────────────────────────────┘       │
│     ↓                                        │
│  ┌──────────────────────────────────┐       │
│  │  PostgreSQL Primary               │       │
│  │  ├── Replica 1 (Read)             │       │
│  │  └── Replica 2 (Read)             │       │
│  └──────────────────────────────────┘       │
└─────────────────────────────────────────────┘
```

### Database Migration Strategy

```bash
# Dùng golang-migrate
migrate -path ./migrations -database "postgresql://..." up

# Tên file migration format:
# 000001_create_users.up.sql
# 000001_create_users.down.sql
# 000002_create_rides.up.sql
# 000002_create_rides.down.sql
```
