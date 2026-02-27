---
description: How to run services locally for development
---

# Run Services

## Run all services at once
```bash
make run-all
```

## Run a single service
```bash
cd services/ride-service && go run cmd/main.go
```

## Run with custom config
```bash
HTTP_PORT=8081 GRPC_PORT=50052 go run cmd/main.go
```

## Service ports (default)

| Service | HTTP | gRPC |
|---------|------|------|
| ride-service | 8080 | 50051 |
| driver-service | 8081 | 50052 |
| user-service | 8082 | 50053 |
| payment-service | 8083 | 50054 |
| matching-service | 8084 | 50055 |
| location-service | 8085 | 50056 |
| trip-service | 8086 | 50057 |
| notification-service | 8087 | 50058 |
