---
name: Golang Backend Development
description: Hướng dẫn phát triển backend microservices bằng Go - coding standards, patterns, và project structure.
---

# Golang Backend Development

## Khi nào dùng skill này?
- Tạo mới hoặc sửa đổi bất kỳ microservice nào
- Cần hiểu project structure và coding conventions
- Debug hoặc optimize Go code

## Tại sao Go?
- **Goroutines**: Xử lý hàng vạn concurrent requests với ít RAM
- **Static typing**: Catch bugs tại compile time
- **Fast compilation**: Build trong vài giây
- **Standard library**: HTTP server, JSON, crypto built-in

## Project Structure (mỗi service)
```
services/{service-name}/
├── cmd/main.go           # Entry point
├── internal/
│   ├── handler/          # HTTP/gRPC handlers (input validation)
│   ├── service/          # Business logic (core domain)
│   ├── repository/       # Data access (DB queries)
│   ├── model/            # Domain models
│   └── config/           # Configuration loading
├── migrations/           # SQL migrations
├── go.mod
├── Dockerfile
└── Makefile
```

## Key Dependencies
```
github.com/gin-gonic/gin          # HTTP framework
google.golang.org/grpc            # gRPC
github.com/redis/go-redis/v9      # Redis client
github.com/jackc/pgx/v5           # PostgreSQL driver
github.com/segmentio/kafka-go     # Kafka client
github.com/eclipse/paho.mqtt.golang # MQTT client
go.uber.org/zap                   # Structured logging
```

## Must-Follow Rules
1. Always pass `context.Context` as first param
2. Always return `error` as last return value
3. Use table-driven tests
4. Use `golangci-lint` for linting
5. No global mutable state

## References
- Coding standards: [rules/CODING-STANDARDS.md](../../rules/CODING-STANDARDS.md)
- Error handling: [rules/ERROR-HANDLING.md](../../rules/ERROR-HANDLING.md)
