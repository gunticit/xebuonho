---
name: gRPC Internal Communication
description: Hướng dẫn triển khai gRPC cho giao tiếp nội bộ giữa các microservices.
---

# gRPC Internal Communication

## Khi nào dùng skill này?
- Định nghĩa API contract giữa các microservices
- Cần giao tiếp nội bộ nhanh hơn REST
- Cần type-safety và code generation

## Tech Stack
- **Proto compiler**: `protoc` v3
- **Go plugin**: `protoc-gen-go`, `protoc-gen-go-grpc`
- **Framework**: `google.golang.org/grpc`

## Proto File Convention
```
proto/
├── common/
│   └── common.proto        # Shared types (Location, Pagination)
├── ride/
│   └── ride_service.proto   # Ride service definitions
├── driver/
│   └── driver_service.proto
├── location/
│   └── location_service.proto
└── payment/
    └── payment_service.proto
```

## Code Generation
```bash
protoc --go_out=. --go-grpc_out=. proto/ride/ride_service.proto
```

## Best Practices
1. **Deadline propagation**: Luôn set timeout cho mỗi call
2. **Connection pooling**: Reuse connections
3. **Health checking**: Implement gRPC health check protocol
4. **Error codes**: Dùng standard gRPC status codes
5. **Interceptors**: Logging, auth, metrics middleware

## References
- Xem chi tiết: [docs/architecture/COMMUNICATION.md](../../docs/architecture/COMMUNICATION.md)
- Proto files: [proto/](../../proto/)
