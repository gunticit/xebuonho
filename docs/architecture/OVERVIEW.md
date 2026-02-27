# 🏗️ Kiến trúc Tổng quan Hệ thống XeBuonHo

## Triết lý thiết kế

Hệ thống được xây dựng dựa trên **3 trụ cột**:

1. **Reliability (Độ tin cậy)**: Không bao giờ mất cuốc xe, không bao giờ sai lệch tiền
2. **Real-time Performance**: Cập nhật vị trí, trạng thái trong vài milliseconds
3. **Resilience (Khả năng phục hồi)**: Tự phục hồi khi mạng yếu, tải đột biến, hoặc service crash

## Tổng quan kiến trúc

```mermaid
graph TB
    subgraph "Client Layer"
        DA["🚗 Driver App<br/>(Kotlin/Swift Native)"]
        RA["📱 Rider App<br/>(Flutter/React Native)"]
        WA["🖥️ Admin Panel<br/>(Web App)"]
    end

    subgraph "Communication Layer"
        MQTT["📡 MQTT Broker<br/>(EMQX/HiveMQ)<br/>QoS 1/2"]
        WS["🔌 WebSocket Gateway<br/>(Socket.io)"]
        REST["🌐 REST API<br/>(HTTPS)"]
    end

    subgraph "API Gateway"
        GW["🚪 API Gateway<br/>(Kong/Envoy)<br/>Rate Limiting, Auth, Load Balancing"]
    end

    subgraph "Microservices (Go)"
        OS["📦 Order Service<br/>Unified Order Management"]
        MCS["🏪 Merchant Service<br/>Nhà hàng, Cửa hàng"]
        RS["Ride Service<br/>Quản lý cuốc xe"]
        DS["Driver Service<br/>Quản lý tài xế"]
        US["User Service<br/>Auth, Profile"]
        PS["Payment Service<br/>Thanh toán, Ví"]
        MS["Matching Service<br/>Bắt cặp tài xế-khách"]
        LS["Location Service<br/>GPS tracking"]
        TS["Trip Service<br/>Lịch sử, Rating"]
        NS["Notification Service<br/>Push, SMS, Email"]
    end

    subgraph "Async Messaging"
        KF["📨 Apache Kafka<br/>Event Streaming"]
    end

    subgraph "Data Layer"
        RD["⚡ Redis Cluster<br/>GEO + Session + Cache"]
        PG["🐘 PostgreSQL<br/>+ PostGIS"]
    end

    subgraph "External Services"
        MAP["🗺️ Maps API<br/>(Goong/Mapbox)"]
        SMS["📱 SMS Gateway"]
        PAY["💳 Payment Gateway"]
    end

    DA -->|MQTT QoS 1| MQTT
    RA -->|WebSocket| WS
    WA -->|HTTPS| REST
    RA -->|HTTPS| REST

    MQTT --> GW
    WS --> GW
    REST --> GW

    GW --> OS & MCS & RS & DS & US & PS & TS

    OS <-->|gRPC| MS
    OS <-->|gRPC| MCS
    OS <-->|gRPC| LS
    OS <-->|gRPC| PS
    RS <-->|gRPC| MS
    RS <-->|gRPC| LS
    RS <-->|gRPC| PS
    MS <-->|gRPC| LS
    TS <-->|gRPC| PS

    OS --> KF
    RS --> KF
    DS --> KF
    KF --> NS
    KF --> PS
    KF --> TS

    LS --> RD
    MS --> RD
    DS --> RD
    OS --> PG
    MCS --> PG
    RS --> PG
    US --> PG
    PS --> PG
    TS --> PG

    LS --> MAP
    MS --> MAP
    NS --> SMS
    PS --> PAY
```

## Luồng dữ liệu chính

### 1. Luồng đặt xe (Ride Request Flow)

```mermaid
sequenceDiagram
    participant R as 📱 Rider App
    participant GW as 🚪 API Gateway
    participant RS as Ride Service
    participant MS as Matching Service
    participant LS as Location Service
    participant RD as ⚡ Redis
    participant KF as 📨 Kafka
    participant DS as Driver Service
    participant MQTT as 📡 MQTT
    participant D as 🚗 Driver App

    R->>GW: POST /rides (pickup, destination)
    GW->>RS: Forward + Auth check
    RS->>RS: Idempotency check (dedup key)
    RS->>MS: gRPC: FindNearbyDrivers()
    MS->>RD: GEORADIUS (lat, lng, 2km)
    RD-->>MS: [driver1, driver2, driver3]
    MS->>LS: gRPC: GetDriverLocations()
    LS-->>MS: Locations + ETA
    MS-->>RS: Best matched driver
    RS->>KF: Event: RIDE_CREATED
    KF->>DS: Consume: Notify driver
    DS->>MQTT: Publish ride request
    MQTT->>D: 📡 New ride notification
    D->>MQTT: Accept ride
    MQTT->>DS: Driver accepted
    DS->>KF: Event: RIDE_ACCEPTED
    KF->>RS: Update ride status
    RS-->>R: WebSocket: Driver is coming!
```

### 2. Luồng cập nhật vị trí (Location Update Flow)

```mermaid
sequenceDiagram
    participant D as 🚗 Driver App
    participant MQTT as 📡 MQTT Broker
    participant LS as Location Service
    participant RD as ⚡ Redis
    participant WS as 🔌 WebSocket
    participant R as 📱 Rider App

    loop Mỗi 3-5 giây
        D->>MQTT: Publish location (lat, lng, heading, speed)
        Note over MQTT: QoS 1 - Đảm bảo delivery
        MQTT->>LS: Forward location update
        LS->>RD: GEOADD driver:{id} lat lng
        LS->>RD: SET driver:{id}:meta {speed, heading, timestamp}
        LS->>WS: Push to subscribed riders
        WS->>R: Real-time driver position
    end
```

### 3. Luồng trạng thái chuyến xe (Trip State Machine)

```mermaid
stateDiagram-v2
    [*] --> SEARCHING: Khách đặt xe
    SEARCHING --> DRIVER_ASSIGNED: Tìm thấy tài xế
    SEARCHING --> CANCELLED: Khách hủy / Timeout
    DRIVER_ASSIGNED --> DRIVER_ARRIVING: Tài xế xác nhận
    DRIVER_ASSIGNED --> CANCELLED: Tài xế từ chối
    DRIVER_ARRIVING --> ARRIVED: Tài xế đến điểm đón
    DRIVER_ARRIVING --> CANCELLED: Khách hủy
    ARRIVED --> IN_PROGRESS: Đã đón khách
    ARRIVED --> CANCELLED: Khách không xuất hiện
    IN_PROGRESS --> COMPLETED: Đến điểm trả
    COMPLETED --> PAID: Thanh toán thành công
    PAID --> [*]
    CANCELLED --> [*]
```

## Microservices Detail

| Service | Trách nhiệm | Giao tiếp | Database |
|---------|-------------|-----------|----------|
| **Order Service** | Unified order management (4 service types) | gRPC, Kafka | PostgreSQL |
| **Merchant Service** | Nhà hàng, cửa hàng, menu | gRPC | PostgreSQL |
| **Ride Service** | Tạo/quản lý cuốc xe, orchestrator | gRPC, Kafka | PostgreSQL |
| **Driver Service** | Đăng ký, trạng thái online/offline | MQTT, gRPC | PostgreSQL |
| **User Service** | Auth, profile, OTP | REST, gRPC | PostgreSQL |
| **Payment Service** | Tính cước, ví, thanh toán | gRPC, Kafka | PostgreSQL |
| **Matching Service** | Thuật toán bắt cặp tài xế-khách | gRPC | Redis |
| **Location Service** | GPS tracking, geofencing | MQTT, gRPC | Redis |
| **Trip Service** | Lịch sử, rating, report | gRPC, Kafka | PostgreSQL |
| **Notification Service** | Push, SMS, Email | Kafka consumer | - |

## Nguyên tắc thiết kế

### Twelve-Factor App
- **Config**: Environment variables, không hardcode
- **Stateless**: Services không lưu state nội bộ, dùng Redis/DB
- **Disposability**: Service có thể restart bất cứ lúc nào

### Domain-Driven Design (DDD)
- Mỗi service sở hữu domain và database riêng
- Communication qua gRPC (sync) và Kafka events (async)
- Không truy cập trực tiếp database của service khác

### Circuit Breaker Pattern
- Khi một service downstream bị lỗi, tự động "ngắt mạch"
- Fallback gracefully thay vì cascade failure
- Tự động retry và phục hồi khi service healthy trở lại
