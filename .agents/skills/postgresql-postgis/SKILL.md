---
name: PostgreSQL + PostGIS
description: Hướng dẫn sử dụng PostgreSQL với PostGIS extension cho lưu trữ dữ liệu và spatial queries.
---

# PostgreSQL + PostGIS

## Khi nào dùng skill này?
- Thiết kế database schema
- Viết spatial queries (tìm kiếm theo vùng, khoảng cách)
- Database migrations
- Query optimization

## Setup
```bash
# Docker with PostGIS
docker run -d --name postgres \
  -e POSTGRES_DB=xebuonho \
  -e POSTGRES_USER=app \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  postgis/postgis:16-3.4
```

## Key PostGIS Functions
```sql
-- Tạo point từ tọa độ
ST_MakePoint(longitude, latitude)::geography

-- Tìm trong bán kính
ST_DWithin(geo1, geo2, distance_meters)

-- Tính khoảng cách (mét)
ST_Distance(geo1, geo2)

-- Tìm nearest
ORDER BY geo1 <-> geo2 LIMIT 5
```

## Migration Tool
```bash
# golang-migrate
migrate -path ./migrations -database "postgresql://app:secret@localhost/xebuonho?sslmode=disable" up
```

## References
- Schema: [docs/architecture/DATA-LAYER.md](../../docs/architecture/DATA-LAYER.md)
