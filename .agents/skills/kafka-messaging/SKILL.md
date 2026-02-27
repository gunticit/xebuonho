---
name: Apache Kafka Messaging
description: Hướng dẫn triển khai Kafka cho event streaming, async messaging, và chống sập khi tải cao.
---

# Apache Kafka Messaging

## Khi nào dùng skill này?
- Triển khai async event processing giữa services
- Cần message queue chống sập khi tải đột biến
- Event sourcing và audit trail

## Setup
```bash
# Docker Compose (xem deployments/docker-compose.dev.yml)
docker-compose up -d kafka
```

## Topics
| Topic | Partitions | Retention | Key |
|-------|-----------|-----------|-----|
| `ride.events` | 6 | 7 days | ride_id |
| `driver.events` | 6 | 1 day | driver_id |
| `payment.events` | 3 | 30 days | ride_id |
| `notification.commands` | 4 | 1 day | user_id |

## Go Client
```go
import "github.com/segmentio/kafka-go"

// Producer
writer := &kafka.Writer{
    Addr:         kafka.TCP("localhost:9092"),
    Topic:        "ride.events",
    Balancer:     &kafka.Hash{},
    RequiredAcks: kafka.RequireAll,
}

// Consumer
reader := kafka.NewReader(kafka.ReaderConfig{
    Brokers: []string{"localhost:9092"},
    Topic:   "ride.events",
    GroupID: "matching-service",
})
```

## Error Handling
- Retry 3x with exponential backoff
- Dead Letter Queue (DLQ) for persistent failures
- Alert on DLQ count > 0

## References
- Xem chi tiết: [docs/architecture/MESSAGE-BROKER.md](../../docs/architecture/MESSAGE-BROKER.md)
