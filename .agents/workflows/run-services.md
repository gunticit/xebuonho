---
description: How to run services locally for development
---

# Run Services

## Run all services at once
```bash
./scripts/run-services.sh
```

## Run API Gateway with PostgreSQL
```bash
HTTP_PORT=8000 DATABASE_URL="postgres://postgres:postgres@localhost:5432/xebuonho?sslmode=disable" JWT_SECRET="dev-secret-change-me-in-production" ./services/api-gateway/bin/api-gateway
```

## Seed Real Database
```bash
docker exec -i xebuonho-postgres psql -U postgres -d xebuonho < migrations/seed_real_data.sql
```

## Service ports (production & dev)

| Service | HTTP | gRPC | Ghi chú |
|---------|------|------|---------|
| api-gateway | 8000 | - | API Gateway chính cho Rider & Driver App |
| ride-service | 8080 | 50051 | Xử lý cuốc xe |
| driver-service | 8081 | 50052 | Xử lý vị trí & nghiệp vụ tài xế |
| user-service | 8091 | 50053 | Xác thực JWT & tài khoản |
| order-service | 8088 | 50058 | Đơn hàng Food / Grocery |
| merchant-service | 8089 | 50059 | Quán ăn & thực đơn |
| PostgreSQL | 5432 | - | PostgreSQL + PostGIS |
| Redis | 6379 | - | Redis GEO & cache |
| EMQX MQTT | 1883 | 18083 | MQTT broker & Dashboard |

