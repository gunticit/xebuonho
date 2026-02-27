# 🚗 XeBuonHo - Ride-Hailing Platform

> Nền tảng gọi xe chuyên nghiệp, thiết kế với kiến trúc microservices, tối ưu cho **độ ổn định cao**, **ít lỗi**, và **khả năng chống chịu tải**.

## 🏗️ Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile Apps                          │
│  🚗 Driver (Kotlin/Swift)    📱 Rider (Flutter/RN)     │
├─────────────┬───────────────────────────┬───────────────┤
│  MQTT       │     WebSocket/Socket.io   │     REST      │
│  (QoS 1/2)  │     (Real-time push)      │    (HTTPS)    │
├─────────────┴───────────────────────────┴───────────────┤
│                   API Gateway (Kong/Envoy)               │
├─────────────────────────────────────────────────────────┤
│              Backend Microservices (Go)                   │
│  Ride │ Driver │ User │ Payment │ Matching │ Location    │
│  Trip │ Notification                                      │
├──────────────────┬──────────────────────────────────────┤
│  gRPC (internal) │     Apache Kafka (async messaging)    │
├──────────────────┴──────────────────────────────────────┤
│  Redis (GEO + Cache)  │  PostgreSQL + PostGIS            │
└─────────────────────────────────────────────────────────┘
```

## 📂 Cấu trúc dự án

```
xebuonho/
├── docs/                  # Tài liệu kiến trúc & best practices
├── rules/                 # Coding standards & guidelines
├── services/              # Backend microservices (Go)
├── proto/                 # gRPC Protocol Buffers
├── pkg/                   # Shared Go packages
├── deployments/           # Docker, K8s configs
├── configs/               # Service configurations
└── .agents/               # Skills & workflows for AI agents
```

## 🚀 Quick Start

```bash
# 1. Start infrastructure
docker-compose -f deployments/docker-compose.dev.yml up -d

# 2. Generate gRPC code
make proto

# 3. Run all services
make run-all
```

## 📚 Documentation

| Tài liệu | Mô tả |
|-----------|--------|
| [Architecture Overview](docs/architecture/OVERVIEW.md) | Tổng quan kiến trúc hệ thống |
| [Communication](docs/architecture/COMMUNICATION.md) | MQTT, WebSocket, gRPC |
| [Data Layer](docs/architecture/DATA-LAYER.md) | Redis GEO, PostgreSQL/PostGIS |
| [Message Broker](docs/architecture/MESSAGE-BROKER.md) | Apache Kafka patterns |
| [Mobile Apps](docs/architecture/MOBILE-APPS.md) | Driver (Native) & Rider (Cross-platform) |
| [Mapping & Routing](docs/architecture/MAPPING-ROUTING.md) | Maps API integration |

## 🛡️ Best Practices

| Nguyên tắc | Mô tả |
|-------------|--------|
| [Idempotency](docs/best-practices/IDEMPOTENCY.md) | Chống duplicate booking & double-charge |
| [Offline-First](docs/best-practices/OFFLINE-FIRST.md) | Sync cơ chế cho tài xế mất sóng |
| [State Machine](docs/best-practices/STATE-MACHINE.md) | Quản lý trạng thái chuyến xe chặt chẽ |

## 🛠️ Tech Stack

| Layer | Technology | Lý do |
|-------|------------|-------|
| Driver Communication | MQTT (EMQX) | QoS đảm bảo không mất dữ liệu khi mạng yếu |
| Rider Communication | WebSocket/Socket.io | Push notification, live tracking |
| Internal RPC | gRPC | Binary protocol, siêu nhanh |
| Backend | Go | Concurrency xuất sắc, ít RAM, ít runtime errors |
| Cache & GEO | Redis | Tìm tài xế gần nhất trong milliseconds |
| Database | PostgreSQL + PostGIS | ACID compliance, spatial queries mạnh mẽ |
| Message Queue | Apache Kafka | Chống sập khi tải cao đột biến |
| Driver App | Kotlin/Swift (Native) | Background location ổn định, tối ưu pin |
| Rider App | Flutter/React Native | Code 1 lần, chạy 2 nền tảng |

## 📄 License

Private - All rights reserved.
# xebuonho
