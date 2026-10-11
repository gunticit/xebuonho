---
name: Redis Geospatial & High-Performance Caching
description: Hướng dẫn sử dụng Redis GEO để định vị tài xế realtime, tìm tài xế gần nhất với GEOSEARCH, và khóa phân tán (Distributed Lock) chống tranh chấp đơn.
---

# Redis Geospatial & High-Performance Caching Guide

## 1. Khi nào dùng skill này?
- Lưu trữ và cập nhật tọa độ GPS theo thời gian thực (Real-time Telemetry) của hàng ngàn tài xế online.
- Tìm kiếm tài xế gần nhất trong bán kính R km với độ trễ siêu thấp (< 5ms) bằng `GEOSEARCH`.
- Phân vùng địa lý (Geo-sharding) theo mã thành phố (`sgn`, `han`, `dad`) tránh điểm nghẽn Single Sorted Set.
- Sử dụng Khóa phân tán (Redis Distributed Lock `SETNX`) để đảm bảo chỉ đúng 1 tài xế nhận cuốc thành công.
- Quản lý phiên đăng nhập (JWT blacklist / session), lưu đệm dữ liệu (Caching) và Idempotency.

---

## 2. Các Lệnh Redis GEO Hiện Đại (Redis 6.2+ & 7.x)

> [!NOTE]
> Lệnh `GEORADIUS` cũ đã bị deprecate từ Redis 6.2. Dự án Xebuonho sử dụng `GEOSEARCH` với cú pháp linh hoạt và hiệu năng tối ưu hơn.

### 2.1. Cập nhật vị trí tài xế (`GEOADD`):
```redis
# GEOADD <key> <longitude> <latitude> <member>
GEOADD drivers:geo:sgn 106.7009 10.7769 "driver:93623b04"
```
*Lưu ý quan trọng*: Thứ tự tham số luôn là `Longitude` (Kinh độ) trước, `Latitude` (Vĩ độ) sau!

### 2.2. Tìm tài xế gần điểm đón khách (`GEOSEARCH`):
```redis
# Tìm tối đa 10 tài xế gần điểm đón (106.7000, 10.7750) trong bán kính 3 km, sắp xếp gần đến xa kèm khoảng cách và tọa độ:
GEOSEARCH drivers:geo:sgn 
    FROMLONLAT 106.7000 10.7750 
    BYRADIUS 3 km 
    ASC 
    COUNT 10 
    WITHDIST 
    WITHCOORD
```

---

## 3. Kiến Trúc Phân Vùng Geo-Sharding & Dọn Dẹp Tài Xế Mất Tín Hiệu

Nếu lưu toàn bộ tài xế toàn quốc vào 1 key duy nhất `active_drivers`, key đó sẽ trở thành điểm nghẽn (Hot Key).

### 3.1. Phân vùng theo thành phố:
- `drivers:geo:sgn`: Khu vực TP. Hồ Chí Minh & lân cận.
- `drivers:geo:han`: Khu vực Hà Nội & vùng Thủ đô.
- `drivers:geo:dad`: Khu vực Đà Nẵng & miền Trung.

### 3.2. Quản lý Heartbeat & Tự động loại bỏ tài xế Offline (Eviction):
Mỗi khi tài xế gửi vị trí lên (mỗi 3-5 giây):
1. `GEOADD drivers:geo:sgn <lng> <lat> <driver_id>`
2. `SET driver:<driver_id>:heartbeat <timestamp> EX 45` (TTL 45 giây)
3. Nếu tài xế mất sóng hoặc tắt app, heartbeat hết hạn (Key Expired). Cronjob nền hoặc Worker quét dọn `ZREM drivers:geo:sgn <driver_id>` để tránh gán cuốc cho tài xế ma.

---

## 4. Khóa Phân Tán Nhận Cuốc Xe (Distributed Lock với `SETNX`)

Khi hàng chục tài xế cùng bật radar quanh 1 cuốc xe `created`:

```go
package dispatch

import (
    "context"
    "errors"
    "time"
    "github.com/redis/go-redis/v9"
)

var ErrRideAlreadyClaimed = errors.New("cuốc xe đã được tài xế khác nhận")

func TryClaimRideLock(ctx context.Context, rdb *redis.Client, rideID, driverID string) (bool, error) {
    lockKey := "lock:ride:" + rideID
    // Set lock có thời hạn 5 giây. Chỉ thành công nếu key CHƯA từng tồn tại
    ok, err := rdb.SetNX(ctx, lockKey, driverID, 5*time.Second).Result()
    if err != nil {
        return false, err
    }
    return ok, nil
}
```

---

## 5. Tổ Chức Khóa & Kiểu Dữ Liệu Trong Toàn Hệ Thống

| Key Pattern | Kiểu dữ liệu | TTL | Mục đích sử dụng |
|---|---|---|---|
| `drivers:geo:{city}` | Sorted Set (GEO) | Vĩnh viễn | Index tọa độ tài xế online đang sẵn sàng |
| `driver:{id}:meta` | Hash | 60 giây | Trạng thái (online, on_trip), xe, rating, pin, tốc độ |
| `driver:{id}:heartbeat` | String | 45 giây | Liveness check phát hiện mất kết nối |
| `ride:{id}` | Hash | 2 giờ | Cache thông tin đơn hàng đang hoạt động |
| `lock:ride:{id}` | String | 5 giây | Distributed Lock chống nhận trùng cuốc |
| `idem:{key}` | String | 24 giờ | X-Idempotency-Key chống gửi lặp thanh toán / đặt xe |
| `rate:ip:{ip}` | String (Counter) | 1 phút | Rate limit API Gateway chống DDOS |

---

## 6. Code Mẫu Go Client với `go-redis/v9`

```go
package main

import (
    "context"
    "fmt"
    "github.com/redis/go-redis/v9"
)

func FindNearbyDrivers(ctx context.Context, rdb *redis.Client, city string, lng, lat, radiusKm float64) ([]redis.GeoLocation, error) {
    key := fmt.Sprintf("drivers:geo:%s", city)
    
    locations, err := rdb.GeoSearchLocation(ctx, key, &redis.GeoSearchLocationQuery{
        GeoSearchQuery: redis.GeoSearchQuery{
            Longitude:  lng,
            Latitude:   lat,
            Radius:     radiusKm,
            RadiusUnit: "km",
            Sort:       "ASC",
            Count:      10,
        },
        WithDist:  true,
        WithCoord: true,
    }).Result()

    return locations, err
}
```

---

## 7. References
- Schema tài liệu: [`docs/architecture/DATA-LAYER.md`](../../docs/architecture/DATA-LAYER.md)
- Microservice vị trí: [`services/location-service/`](../../services/location-service/)
- Microservice điều phối: [`services/matching-service/`](../../services/matching-service/)
- Skill bảo mật: [`skills/security-anti-fraud/SKILL.md`](../security-anti-fraud/SKILL.md)
