# 🚗 XeBuonHo - Super App Platform

> Nền tảng **đa dịch vụ** hỗ trợ 4 loại: **Chở khách** · **Đặt đồ ăn** · **Đi chợ hộ** · **Lái xe hộ**

## 🎯 4 Service Types

| Service | Mô tả | Trạng thái |
|---------|--------|-----------|
| 🚗 **Chở khách** | A→B transport, đón khách chở đến điểm trả | ✅ |
| 🍔 **Đặt đồ ăn** | Khách chọn món → Quán nấu → Tài xế giao | ✅ |
| 🛒 **Đi chợ hộ** | Khách gửi list → Tài xế mua + giao | ✅ |
| 🚙 **Lái xe hộ** | Tài xế đến lái xe CỦA KHÁCH | ✅ |

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile Apps                          │
│  🚗 Driver (Kotlin/Swift)    📱 Customer (Flutter/RN)  │
│  🏪 Merchant App (Web/Mobile)                          │
├─────────────┬───────────────────────────┬───────────────┤
│  MQTT       │     WebSocket/Socket.io   │     REST      │
├─────────────┴───────────────────────────┴───────────────┤
│                   API Gateway                           │
├─────────────────────────────────────────────────────────┤
│              Backend Microservices (Go)                   │
│  Order │ Merchant │ Ride │ Driver │ User │ Payment      │
│  Matching │ Location │ Trip │ Notification              │
├──────────────────┬──────────────────────────────────────┤
│  gRPC (internal) │     Apache Kafka (async)             │
├──────────────────┴──────────────────────────────────────┤
│  Redis (GEO + Cache)  │  PostgreSQL + PostGIS            │
└─────────────────────────────────────────────────────────┘
```

## 📂 Cấu trúc dự án

```
xebuonho/
├── docs/
│   ├── architecture/    # OVERVIEW, SERVICES, COMMUNICATION, DATA-LAYER, ...
│   ├── best-practices/  # IDEMPOTENCY, OFFLINE-FIRST, STATE-MACHINE
│   └── api/             # API documentation
├── rules/               # CODING-STANDARDS, ERROR-HANDLING, SECURITY, PERFORMANCE
├── services/            # 10 Go microservices
│   ├── order-service/      # 📦 Unified order management (4 service types)
│   ├── merchant-service/   # 🏪 Restaurant/store management
│   ├── ride-service/       # 🚗 Ride management
│   ├── driver-service/     # 👨‍✈️ Driver management
│   ├── user-service/       # 👤 Auth, profiles
│   ├── payment-service/    # 💳 Payments, wallet
│   ├── matching-service/   # 🎯 Driver-customer matching
│   ├── location-service/   # 📍 GPS tracking
│   ├── trip-service/       # 📋 History, ratings
│   └── notification-service/ # 🔔 Push, SMS, email
├── proto/               # gRPC Protocol Buffers
│   ├── common/          # Shared types (ServiceType, Location, Money)
│   ├── order/           # Unified Order model
│   ├── merchant/        # Merchant, Menu, MenuItem
│   ├── ride/            # Ride-specific
│   ├── location/        # Location tracking
│   ├── driver/          # Driver management
│   └── payment/         # Payment processing
├── pkg/                 # Shared Go packages
│   └── statemachine/    # State machines for all 4 service types
├── deployments/         # Docker Compose, K8s
├── .agents/             # Skills & workflows
│   ├── skills/          # 13 skills (mqtt, grpc, food-delivery, grocery, ...)
│   └── workflows/       # setup-dev, run-services
├── Makefile
├── go.work
└── README.md
```

## 🚀 Quick Start

```bash
# 1. Start infrastructure
make docker-up

# 2. Run all services
make run-all

# 3. Check health
curl http://localhost:8088/health  # Order Service
```

## 📚 Documentation

| Tài liệu | Mô tả |
|-----------|--------|
| [Architecture Overview](docs/architecture/OVERVIEW.md) | Tổng quan hệ thống |
| [**Services (4 types)**](docs/architecture/SERVICES.md) | Chi tiết 4 service types |
| [Communication](docs/architecture/COMMUNICATION.md) | MQTT, WebSocket, gRPC |
| [Data Layer](docs/architecture/DATA-LAYER.md) | Redis GEO, PostgreSQL/PostGIS |
| [Message Broker](docs/architecture/MESSAGE-BROKER.md) | Apache Kafka |
| [Mobile Apps](docs/architecture/MOBILE-APPS.md) | Native Driver + Cross-platform |
| [Mapping & Routing](docs/architecture/MAPPING-ROUTING.md) | Maps API, fare calculation |

## 🛡️ Best Practices

- [Idempotency](docs/best-practices/IDEMPOTENCY.md) - Chống duplicate booking
- [Offline-First](docs/best-practices/OFFLINE-FIRST.md) - Sync khi mất mạng
- [State Machine](docs/best-practices/STATE-MACHINE.md) - Quản lý trạng thái chặt chẽ

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| Driver ↔ Server | MQTT (EMQX) |
| Customer ↔ Server | WebSocket/Socket.io |
| Internal RPC | gRPC |
| Backend | Go |
| Cache & GEO | Redis |
| Database | PostgreSQL + PostGIS |
| Message Queue | Apache Kafka |
| Driver App | Kotlin/Swift (Native) |
| Customer App | Flutter/React Native |

## 📄 License

Private - All rights reserved.
# xebuonho
