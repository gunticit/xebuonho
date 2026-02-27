---
name: Redis Geospatial
description: Hướng dẫn sử dụng Redis GEO để tìm tài xế gần nhất, lưu vị trí realtime, và caching.
---

# Redis Geospatial

## Khi nào dùng skill này?
- Lưu/truy vấn vị trí tài xế realtime
- Tìm tài xế gần nhất trong bán kính X km
- Caching session, ride data, driver metadata

## Key Commands
```redis
GEOADD active_drivers <lng> <lat> "driver:<id>"
GEORADIUS active_drivers <lng> <lat> <radius> km COUNT 5 ASC
GEODIST active_drivers "driver:a" "driver:b" km
GEOSEARCH active_drivers FROMLONLAT <lng> <lat> BYRADIUS <r> km ASC COUNT 5
```

## Go Client Setup
```go
import "github.com/redis/go-redis/v9"

client := redis.NewClient(&redis.Options{
    Addr: "localhost:6379",
    DB:   0,
})
```

## Data Organization
| Key Pattern | Type | TTL | Mô tả |
|------------|------|-----|--------|
| `active_drivers` | GEO (Sorted Set) | - | Vị trí tất cả tài xế online |
| `driver:{id}:meta` | Hash | 60s | Speed, heading, battery, vehicle_type |
| `ride:{id}` | Hash | 1h | Cache ride data |
| `session:{token}` | String | 15min | User session |
| `idem:{key}` | String | 5min | Idempotency cache |

## References
- Xem chi tiết: [docs/architecture/DATA-LAYER.md](../../docs/architecture/DATA-LAYER.md)
- Code: [pkg/redis/](../../pkg/redis/)
