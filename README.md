# 🏍️ Xebuonho — Nền tảng gọi xe & giao hàng

## Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────────┐
│                     CLIENTS                             │
│   📱 Rider App (Flutter)     📱 Driver App (Native)    │
└──────────────┬──────────────────────┬───────────────────┘
               │ HTTP/WS             │ MQTT
┌──────────────▼──────────────────────▼───────────────────┐
│              API Gateway (:8000)                         │
└──────────────┬──────────────────────────────────────────┘
               │ gRPC
┌──────────────▼──────────────────────────────────────────┐
│                  MICROSERVICES                           │
│  ride-service   │ user-service   │ order-service        │
│  driver-service │ payment-service│ merchant-service     │
│  matching-service│location-service│ notification-service│
│  trip-service   │                │                      │
└──────────────┬──────────┬────────┬──────────────────────┘
               │          │        │
┌──────────────▼──┐ ┌─────▼────┐ ┌─▼────────┐ ┌─────────┐
│ PostgreSQL+     │ │  Redis   │ │  Kafka   │ │  EMQX   │
│ PostGIS         │ │  GEO     │ │  Events  │ │  MQTT   │
└─────────────────┘ └──────────┘ └──────────┘ └─────────┘
```

---

## ⚡ Quick Start

### Yêu cầu hệ thống

| Tool | Version | Kiểm tra |
|------|---------|----------|
| **Go** | 1.22+ | `go version` |
| **Flutter** | 3.x+ | `flutter --version` |
| **Docker** | 20+ | `docker --version` |
| **Docker Compose** | v2+ | `docker compose version` |

### 1️⃣ Clone & Setup

```bash
# Clone repo
git clone <repo-url> xebuonho
cd xebuonho

# Copy env
cp .env.example .env
```

### 2️⃣ Khởi động Infrastructure

```bash
# Start PostgreSQL, Redis, Kafka, EMQX
make docker-up

# Kiểm tra containers đang chạy
docker ps
```

**Kết quả mong đợi:**

| Container | Port | Mô tả |
|-----------|------|--------|
| xebuonho-postgres | 5432 | PostgreSQL + PostGIS |
| xebuonho-redis | 6379 | Redis (cache + GEO) |
| xebuonho-kafka | 9092 | Kafka broker |
| xebuonho-zookeeper | 2181 | Zookeeper |
| xebuonho-emqx | 1883, 18083 | MQTT broker |
| xebuonho-kafka-ui | 8090 | Kafka UI dashboard |

### 3️⃣ Chạy Database Migrations

```bash
make migrate-up DATABASE_URL="postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"
```

### 4️⃣ Chạy Backend Services

**Tất cả cùng lúc:**
```bash
make run-all
```

**Hoặc từng service:**
```bash
# API Gateway (cổng chính cho client)
cd services/api-gateway && go run cmd/main.go

# User Service (đăng ký, đăng nhập, OTP)
cd services/user-service && HTTP_PORT=8091 go run cmd/main.go

# Ride Service
cd services/ride-service && go run cmd/main.go
```

### 5️⃣ Chạy Rider App (Flutter)

```bash
cd apps/rider

# Cài dependencies
flutter pub get

# Chạy trên Chrome (web)
flutter run -d chrome

# Chạy trên iOS Simulator
flutter run -d ios

# Chạy trên Android Emulator
flutter run -d android
```

> **Lưu ý:** App có **demo mode** — nếu backend chưa chạy, app vẫn hoạt động với dữ liệu giả.

---

## 📡 Service Ports

| Service | HTTP | gRPC | Mô tả |
|---------|------|------|--------|
| **api-gateway** | 8000 | — | Cổng vào chính, JWT auth |
| **ride-service** | 8080 | 50051 | Quản lý chuyến xe |
| **user-service** | 8091 | 50053 | Auth, profile, OTP |
| **driver-service** | 8081 | 50052 | Quản lý tài xế |
| **payment-service** | 8083 | 50054 | Thanh toán |
| **matching-service** | 8084 | 50055 | Ghép tài xế - khách |
| **location-service** | 8085 | 50056 | Vị trí realtime |
| **trip-service** | 8086 | 50057 | Lịch sử chuyến |
| **notification-service** | 8092 | 50058 | Push notifications |
| **order-service** | 8088 | 50058 | Đơn hàng đồ ăn |
| **merchant-service** | 8089 | 50059 | Quản lý nhà hàng |

---

## 🖥️ Dashboards

| Dashboard | URL | Credentials |
|-----------|-----|-------------|
| EMQX (MQTT) | http://localhost:18083 | admin / public |
| Kafka UI | http://localhost:8090 | — |
| Rider App | http://localhost:PORT | Tự động khi `flutter run` |

---

## 📱 Rider App — Cấu trúc

```
apps/rider/lib/
├── main.dart              # 25 routes
├── config/
│   └── theme.dart         # Design system (dark theme)
├── models/
│   └── app_models.dart    # Data models
├── providers/
│   ├── auth_provider.dart
│   ├── booking_provider.dart
│   └── location_provider.dart
├── services/
│   ├── api_service.dart
│   ├── geocoding_service.dart
│   └── notification_service.dart
├── screens/
│   ├── splash_screen.dart      # Consent dialog first-launch
│   ├── onboarding_screen.dart  # 3-slide intro
│   ├── login_screen.dart       # Đăng nhập/Đăng ký
│   ├── otp_screen.dart         # Xác thực OTP
│   ├── home_screen.dart        # Bản đồ + dịch vụ
│   ├── search_screen.dart      # Tìm kiếm + gợi ý địa chỉ
│   ├── booking_screen.dart     # Đặt xe
│   ├── tracking_screen.dart    # Theo dõi realtime
│   ├── ride_complete_screen.dart
│   ├── ride_detail_screen.dart
│   ├── profile_screen.dart
│   ├── payment_screen.dart
│   ├── top_up_screen.dart      # Nạp tiền ví
│   ├── history_screen.dart
│   ├── settings_screen.dart
│   ├── saved_addresses_screen.dart
│   ├── chat_screen.dart        # Chat + Report/Block
│   ├── legal_screens.dart      # Privacy Policy + Terms
│   └── food/
│       ├── restaurant_list_screen.dart
│       └── restaurant_detail_screen.dart
└── widgets/
    ├── app_drawer.dart
    ├── consent_dialog.dart     # GDPR consent
    └── sos_schedule.dart       # SOS + lịch đặt xe
```

---

## 🔧 Các lệnh hữu ích

```bash
# === Docker ===
make docker-up          # Bật infrastructure
make docker-down        # Tắt infrastructure

# === Backend ===
make run-all            # Chạy tất cả services
make build              # Build tất cả services
make test               # Chạy tests
make lint               # Kiểm tra code quality
make tidy               # Go mod tidy tất cả

# === Database ===
make migrate-up DATABASE_URL="..."    # Chạy migrations
make migrate-create SERVICE=ride-service NAME=add_field  # Tạo migration mới

# === gRPC ===
make proto              # Generate code từ .proto files

# === Rider App ===
cd apps/rider
flutter pub get         # Cài packages
flutter run -d chrome   # Chạy web
flutter run -d ios      # Chạy iOS
flutter build web       # Build production web
flutter build apk       # Build Android APK
flutter build ios       # Build iOS
```

---

## 🐛 Xử lý lỗi thường gặp

### Flutter: `Operation not permitted`
```bash
# macOS Sequoia gây lỗi — fix:
sudo xattr -r -d com.apple.quarantine /opt/homebrew/share/flutter
```

### Docker: Không connect được
```bash
# Kiểm tra Docker daemon
docker info

# Reset volumes nếu cần
make docker-down
docker volume prune
make docker-up
```

### Backend: Port đã dùng
```bash
# Tìm process chiếm port
lsof -i :8080
kill -9 <PID>
```

---

## 📦 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.x (Dart) |
| **Backend** | Go 1.22 (Microservices) |
| **API Gateway** | Go + Chi Router |
| **Communication** | gRPC (internal), REST (external) |
| **Database** | PostgreSQL 16 + PostGIS |
| **Cache** | Redis 7 |
| **Message Queue** | Apache Kafka |
| **Realtime** | EMQX (MQTT) + WebSocket |
| **Maps** | OpenStreetMap (Nominatim) |
| **Auth** | JWT + OTP |
| **Container** | Docker + Docker Compose |
