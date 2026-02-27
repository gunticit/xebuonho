---
description: How to set up the development environment and run all services locally
---

# Setup Development Environment

## Prerequisites
- Go 1.22+
- Docker & Docker Compose
- `protoc` (Protocol Buffers compiler)
- `protoc-gen-go` and `protoc-gen-go-grpc` plugins
- `golang-migrate` (for DB migrations)
- `golangci-lint` (for linting)

## Steps

// turbo-all

1. Start infrastructure services:
```bash
make docker-up
```

2. Verify services are running:
```bash
docker ps
```
Expected: postgres, redis, kafka, zookeeper, emqx, kafka-ui

3. Access dashboards:
- EMQX Dashboard: http://localhost:18083 (admin/public)
- Kafka UI: http://localhost:8090

4. Generate gRPC code (if proto files changed):
```bash
make proto
```

5. Run database migrations:
```bash
make migrate-up DATABASE_URL="postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"
```

6. Run all services:
```bash
make run-all
```

7. Check health:
```bash
curl http://localhost:8080/health
```
