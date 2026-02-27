# 📨 Message Broker - Apache Kafka

> Bí quyết **"Chống sập"** và **"Không rớt cuốc"** khi tải đột biến.

## Vấn đề cần giải quyết

```
Trời mưa lớn → Lượng đặt xe tăng vọt 10x
                    ↓
Server xử lý ngay lập tức → QUÁ TẢI → SẬP
                    ↓
Giải pháp: Kafka làm "hàng đợi" (Queue)
                    ↓
Request xếp hàng → Server từ từ xử lý → KHÔNG SẬP
```

## Tại sao Apache Kafka?

| Tiêu chí | Kafka | RabbitMQ |
|----------|-------|----------|
| **Throughput** | Triệu msg/s | Vạn msg/s |
| **Durability** | Lưu trên disk, replay được | Mất sau khi consume |
| **Ordering** | Đảm bảo trong partition | Đảm bảo trong queue |
| **Scalability** | Horizontal scaling xuất sắc | Có giới hạn |
| **Use case** | Event streaming, log aggregation | Task queue, RPC |
| **Phù hợp cho** | Ride-hailing ✅ | Microservices messaging |

> **Đề xuất**: Dùng **Kafka** làm primary, **RabbitMQ** optional cho các task đơn giản (send email, SMS).

---

## Kafka Topics Architecture

```
┌─────────────────────────────────────────────────┐
│                 KAFKA CLUSTER                    │
├─────────────────────────────────────────────────┤
│                                                  │
│  Topic: ride.events (3 partitions)               │
│  ├── P0: [CREATED, ASSIGNED, ARRIVED, ...]       │
│  ├── P1: [CREATED, CANCELLED, CREATED, ...]      │
│  └── P2: [COMPLETED, PAID, CREATED, ...]         │
│  Key: ride_id → Same ride always same partition   │
│                                                  │
│  Topic: driver.events (3 partitions)              │
│  ├── P0: [ONLINE, LOCATION, OFFLINE, ...]        │
│  ├── P1: [ONLINE, ACCEPTED, COMPLETED, ...]      │
│  └── P2: [LOCATION, LOCATION, OFFLINE, ...]      │
│  Key: driver_id                                   │
│                                                  │
│  Topic: payment.events (2 partitions)             │
│  ├── P0: [INITIATED, COMPLETED, ...]             │
│  └── P1: [INITIATED, FAILED, RETRY, ...]         │
│  Key: ride_id                                     │
│                                                  │
│  Topic: notification.commands (2 partitions)      │
│  ├── P0: [PUSH, SMS, EMAIL, ...]                 │
│  └── P1: [PUSH, PUSH, SMS, ...]                  │
│  Key: user_id                                     │
│                                                  │
│  Topic: analytics.events (4 partitions)           │
│  └── All events for analytics pipeline            │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Topic Configuration

```yaml
# Kafka topic configurations
topics:
  ride.events:
    partitions: 6
    replication_factor: 3
    retention_ms: 604800000        # 7 days
    cleanup_policy: delete
    min_insync_replicas: 2         # ← Đảm bảo data safety

  driver.events:
    partitions: 6
    replication_factor: 3
    retention_ms: 86400000         # 1 day
    cleanup_policy: delete

  payment.events:
    partitions: 3
    replication_factor: 3
    retention_ms: 2592000000       # 30 days (quan trọng, giữ lâu)
    cleanup_policy: delete
    min_insync_replicas: 2

  notification.commands:
    partitions: 4
    replication_factor: 2
    retention_ms: 86400000         # 1 day
```

---

## Event Schema (CloudEvents format)

```json
{
    "specversion": "1.0",
    "type": "ride.created",
    "source": "/services/ride-service",
    "id": "evt-uuid-here",
    "time": "2025-01-15T10:30:00Z",
    "datacontenttype": "application/json",
    "data": {
        "ride_id": "ride-uuid",
        "rider_id": "user-uuid",
        "pickup": {"lat": 10.8231, "lng": 106.6297},
        "dropoff": {"lat": 10.7915, "lng": 106.7012},
        "vehicle_type": "car",
        "fare_estimate": 85000,
        "idempotency_key": "rider-uuid-1705312200"
    }
}
```

### Ride Events Flow

```
ride.created          → Matching Service (tìm tài xế)
                      → Analytics Service (tracking)

ride.driver_assigned  → Notification Service (push to rider)
                      → Driver Service (update status to busy)

ride.driver_arriving  → Notification Service (push ETA to rider)

ride.arrived          → Notification Service (push to rider)

ride.in_progress      → Payment Service (start metering)
                      → Analytics Service

ride.completed        → Payment Service (calculate final fare)
                      → Trip Service (save history)
                      → Analytics Service

ride.cancelled        → Payment Service (refund if needed)
                      → Matching Service (release driver)
                      → Analytics Service

payment.completed     → Notification Service (receipt to both)
                      → Driver Service (update earnings)
```

---

## Consumer Groups

```
┌─────────────────────────────────────────────┐
│ Topic: ride.events                           │
│                                              │
│ Consumer Group: matching-service             │
│   Consumer 1 ←── Partition 0, 1             │
│   Consumer 2 ←── Partition 2, 3             │
│   Consumer 3 ←── Partition 4, 5             │
│                                              │
│ Consumer Group: notification-service         │
│   Consumer 1 ←── Partition 0, 1, 2          │
│   Consumer 2 ←── Partition 3, 4, 5          │
│                                              │
│ Consumer Group: analytics-service            │
│   Consumer 1 ←── All partitions             │
│                                              │
│ → Mỗi group đọc TOÀN BỘ events              │
│ → Trong 1 group, mỗi partition chỉ 1 reader │
└─────────────────────────────────────────────┘
```

---

## Go Kafka Producer/Consumer

```go
package kafka

import (
    "context"
    "encoding/json"
    "time"
    
    "github.com/segmentio/kafka-go"
)

// Producer - Gửi events
type EventProducer struct {
    writer *kafka.Writer
}

func NewEventProducer(brokers []string, topic string) *EventProducer {
    return &EventProducer{
        writer: &kafka.Writer{
            Addr:         kafka.TCP(brokers...),
            Topic:        topic,
            Balancer:     &kafka.Hash{},       // ← Key-based partitioning
            RequiredAcks: kafka.RequireAll,     // ← Wait for ALL replicas
            Async:        false,                // ← Sync write for safety
            BatchTimeout: 10 * time.Millisecond,
        },
    }
}

func (p *EventProducer) PublishRideEvent(ctx context.Context, rideID string, event interface{}) error {
    value, err := json.Marshal(event)
    if err != nil {
        return err
    }
    
    return p.writer.WriteMessages(ctx, kafka.Message{
        Key:   []byte(rideID),    // ← Same ride always same partition
        Value: value,
        Headers: []kafka.Header{
            {Key: "event_type", Value: []byte("ride.created")},
            {Key: "source", Value: []byte("ride-service")},
        },
    })
}

// Consumer - Đọc events
type EventConsumer struct {
    reader *kafka.Reader
}

func NewEventConsumer(brokers []string, topic, groupID string) *EventConsumer {
    return &EventConsumer{
        reader: kafka.NewReader(kafka.ReaderConfig{
            Brokers:        brokers,
            Topic:          topic,
            GroupID:         groupID,
            MinBytes:       1e3,              // 1KB
            MaxBytes:       10e6,             // 10MB
            CommitInterval: time.Second,      // Auto-commit offset
            StartOffset:    kafka.LastOffset, // Chỉ đọc message mới
        }),
    }
}

func (c *EventConsumer) Listen(ctx context.Context, handler func(msg kafka.Message) error) error {
    for {
        msg, err := c.reader.ReadMessage(ctx)
        if err != nil {
            return err
        }
        
        if err := handler(msg); err != nil {
            // Log error, có thể push to Dead Letter Queue
            log.Errorf("Failed to handle message: %v", err)
            continue
        }
    }
}
```

---

## Retry & Dead Letter Queue (DLQ)

```
Message fails → Retry 3 times (exponential backoff)
                    ↓ still fails
              Push to DLQ topic
                    ↓
              Alert + Manual review
                    ↓
              Fix & Replay from DLQ
```

```
ride.events          → Consumer fails
ride.events.retry.1  → 1st retry (after 1s)
ride.events.retry.2  → 2nd retry (after 5s)
ride.events.retry.3  → 3rd retry (after 30s)
ride.events.dlq      → Dead Letter Queue (manual review)
```

## Monitoring

| Metric | Alert threshold | Ý nghĩa |
|--------|----------------|---------|
| Consumer lag | > 10,000 | Consumer xử lý chậm |
| Produce rate | Sudden spike 5x | Tải đột biến |
| Error rate | > 1% | Có vấn đề trong consumer |
| DLQ count | > 0 | Có message bị lỗi cần review |
