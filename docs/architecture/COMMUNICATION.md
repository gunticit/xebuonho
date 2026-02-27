# 📡 Công nghệ Giao tiếp Real-time

> **Trái tim của hệ thống** - Chọn đúng giao thức cho đúng use case.

## Tổng quan 3 tầng giao tiếp

| Tầng | Giao thức | Dùng cho | Lý do |
|------|-----------|----------|-------|
| Driver ↔ Server | **MQTT** | GPS tracking, ride notifications | Siêu nhẹ, QoS, hoạt động tốt trên mạng yếu |
| Rider ↔ Server | **WebSocket** | Live tracking, chat, notifications | Full-duplex, mượt mà trên mạng ổn định |
| Service ↔ Service | **gRPC** | Internal API calls | Binary protocol, type-safe, siêu nhanh |

---

## 1. MQTT - Dành cho App Tài xế

### Tại sao MQTT là bắt buộc?

Tài xế di chuyển liên tục → mạng di động chuyển trạm BTS → mất sóng khi vào hầm/khu vực lõm. MQTT được thiết kế riêng cho môi trường **mạng không ổn định**.

### Cơ chế QoS (Quality of Service)

```
┌──────────┬────────────────────────────────────────────────┐
│ QoS 0    │ "Fire and forget" - Gửi 1 lần, không quan     │
│          │ tâm nhận được không. Dùng cho location update  │
│          │ không quan trọng (mỗi 1s, mất 1-2 cũng ok)    │
├──────────┼────────────────────────────────────────────────┤
│ QoS 1    │ "At least once" - Đảm bảo nhận được ít nhất   │
│          │ 1 lần. DÙNG CHO: location update chính,        │
│          │ ride notifications. ĐỀ XUẤT MẶC ĐỊNH.         │
├──────────┼────────────────────────────────────────────────┤
│ QoS 2    │ "Exactly once" - Đảm bảo nhận đúng 1 lần.     │
│          │ Dùng cho: accept/reject ride, status changes.   │
│          │ Tốn tài nguyên nhất nhưng KHÔNG ĐƯỢC MẤT.      │
└──────────┴────────────────────────────────────────────────┘
```

### MQTT Topics Structure

```
# Driver location updates
drivers/{driver_id}/location          → QoS 1
  Payload: { lat, lng, heading, speed, timestamp, battery }

# Driver status (online/offline/busy)
drivers/{driver_id}/status            → QoS 2
  Payload: { status: "online"|"offline"|"busy", timestamp }

# Ride requests to driver
drivers/{driver_id}/rides/request     → QoS 2
  Payload: { ride_id, pickup, destination, fare_estimate, timeout_seconds }

# Driver response (accept/reject)
drivers/{driver_id}/rides/response    → QoS 2
  Payload: { ride_id, action: "accept"|"reject", timestamp }

# Trip status updates from driver
trips/{trip_id}/status                → QoS 2
  Payload: { status, timestamp, location }

# System commands to driver
drivers/{driver_id}/commands          → QoS 1
  Payload: { type: "force_logout"|"update_config", data }
```

### MQTT Broker: EMQX Configuration

```yaml
# emqx.conf key settings
listener.tcp.external = 0.0.0.0:1883
listener.ssl.external = 0.0.0.0:8883
listener.ws.external  = 0.0.0.0:8083

# Authentication
auth.jwt.secret = ${MQTT_JWT_SECRET}
auth.jwt.from = password

# Session persistence (critical for reconnection)
zone.external.session_expiry_interval = 7200  # 2 hours
zone.external.max_inflight = 32
zone.external.max_mqueue_len = 1000

# Clustering for HA
cluster.name = xebuonho
cluster.discovery = dns
cluster.dns.name = emqx-headless.default.svc.cluster.local
```

### Go MQTT Client Example

```go
package mqtt

import (
    "fmt"
    "time"
    mqttclient "github.com/eclipse/paho.mqtt.golang"
)

type DriverMQTTClient struct {
    client   mqttclient.Client
    driverID string
}

func NewDriverMQTTClient(brokerURL, driverID, token string) *DriverMQTTClient {
    opts := mqttclient.NewClientOptions().
        AddBroker(brokerURL).
        SetClientID(fmt.Sprintf("driver-%s", driverID)).
        SetUsername(driverID).
        SetPassword(token).  // JWT token
        SetKeepAlive(30 * time.Second).
        SetAutoReconnect(true).                    // ← KEY: Tự động reconnect
        SetMaxReconnectInterval(30 * time.Second). // ← Tối đa 30s giữa các lần retry
        SetCleanSession(false).                    // ← KEY: Giữ session, nhận message bù
        SetResumeSubs(true).                       // ← KEY: Tự subscribe lại
        SetConnectionLostHandler(func(c mqttclient.Client, err error) {
            log.Warnf("MQTT connection lost for driver %s: %v", driverID, err)
        }).
        SetOnConnectHandler(func(c mqttclient.Client) {
            log.Infof("MQTT reconnected for driver %s", driverID)
            // Re-subscribe to driver-specific topics
            c.Subscribe(fmt.Sprintf("drivers/%s/rides/request", driverID), 2, nil)
            c.Subscribe(fmt.Sprintf("drivers/%s/commands", driverID), 1, nil)
        })

    client := mqttclient.NewClient(opts)
    return &DriverMQTTClient{client: client, driverID: driverID}
}

// PublishLocation gửi vị trí với QoS 1
func (d *DriverMQTTClient) PublishLocation(lat, lng, heading, speed float64) error {
    topic := fmt.Sprintf("drivers/%s/location", d.driverID)
    payload := fmt.Sprintf(`{"lat":%.6f,"lng":%.6f,"heading":%.1f,"speed":%.1f,"ts":%d}`,
        lat, lng, heading, speed, time.Now().Unix())
    
    token := d.client.Publish(topic, 1, false, payload) // QoS 1
    token.Wait()
    return token.Error()
}

// PublishStatus gửi trạng thái với QoS 2 (exactly once)
func (d *DriverMQTTClient) PublishStatus(status string) error {
    topic := fmt.Sprintf("drivers/%s/status", d.driverID)
    payload := fmt.Sprintf(`{"status":"%s","ts":%d}`, status, time.Now().Unix())
    
    token := d.client.Publish(topic, 2, true, payload) // QoS 2 + Retained
    token.Wait()
    return token.Error()
}
```

---

## 2. WebSocket / Socket.io - Dành cho App Khách hàng

### Tại sao dùng WebSocket cho Rider?

Khách hàng thường **đứng yên** hoặc ở nơi có Wi-Fi/4G ổn định. WebSocket cung cấp **full-duplex** connection, server chủ động push data realtime tới client.

### Socket.io Events

```javascript
// === SERVER SIDE (Node.js / Go adapter) ===

// Namespace: /rides
io.of('/rides').on('connection', (socket) => {
    const userId = socket.handshake.auth.userId;
    
    // Rider subscribes to their active ride
    socket.on('subscribe:ride', (rideId) => {
        socket.join(`ride:${rideId}`);
    });
    
    // Push driver location to rider
    // Triggered by Location Service via internal event
    socket.on('driver:location', (data) => {
        io.of('/rides').to(`ride:${data.rideId}`).emit('driver:location', {
            lat: data.lat,
            lng: data.lng,
            heading: data.heading,
            eta: data.eta,         // ETA cập nhật realtime
            timestamp: data.ts
        });
    });
    
    // Push ride status changes
    socket.on('ride:status', (data) => {
        io.of('/rides').to(`ride:${data.rideId}`).emit('ride:status', {
            status: data.status,   // 'driver_arriving', 'arrived', 'in_progress'
            message: data.message,
            timestamp: data.ts
        });
    });
});

// === CLIENT EVENTS ===
// Events mà server emit tới Rider App:
// 'driver:location'  → Vẽ xe di chuyển trên bản đồ
// 'ride:status'       → Cập nhật trạng thái chuyến
// 'driver:arriving'   → "Tài xế đang đến trong 3 phút"
// 'chat:message'      → Tin nhắn từ tài xế
// 'fare:update'       → Cập nhật giá cước (nếu có phụ thu)
```

### Connection Management

```
┌─────────────────────────────────────────────────┐
│ WebSocket Connection Lifecycle                   │
├─────────────────────────────────────────────────┤
│                                                  │
│  Connect → Authenticate → Join Room → Listen    │
│     ↓                                     ↓     │
│  Disconnect ← Heartbeat timeout (30s)     │     │
│     ↓                                     │     │
│  Auto-reconnect (Socket.io built-in)      │     │
│     ↓                                     │     │
│  Re-authenticate → Re-join rooms          │     │
│                                                  │
│  Fallback: Long-polling nếu WS bị block   │     │
└─────────────────────────────────────────────────┘
```

---

## 3. gRPC - Giao tiếp nội bộ Backend

### Tại sao gRPC cho service-to-service?

- **Binary protocol** (Protocol Buffers): nhỏ hơn JSON 5-10 lần
- **Type-safe**: Contract rõ ràng, compile-time check
- **HTTP/2**: Multiplexing, header compression
- **Streaming**: Hỗ trợ bidirectional streaming

### Service Definitions

```protobuf
// proto/location/location.proto
syntax = "proto3";
package location;

service LocationService {
    // Unary: Lấy vị trí 1 tài xế
    rpc GetDriverLocation(GetDriverLocationRequest) returns (DriverLocation);
    
    // Unary: Tìm tài xế gần
    rpc FindNearbyDrivers(FindNearbyRequest) returns (FindNearbyResponse);
    
    // Server streaming: Subscribe location updates
    rpc StreamDriverLocation(StreamRequest) returns (stream DriverLocation);
    
    // Client streaming: Batch location updates từ driver
    rpc BatchUpdateLocations(stream LocationUpdate) returns (BatchResponse);
}

message FindNearbyRequest {
    double latitude = 1;
    double longitude = 2;
    double radius_km = 3;         // Bán kính tìm kiếm
    int32 max_results = 4;        // Giới hạn kết quả
    repeated string vehicle_types = 5; // "car", "bike", "premium"
}

message FindNearbyResponse {
    repeated NearbyDriver drivers = 1;
}

message NearbyDriver {
    string driver_id = 1;
    double latitude = 2;
    double longitude = 3;
    double distance_km = 4;
    int32 eta_seconds = 5;        // Thời gian ước tính đến
    string vehicle_type = 6;
    float rating = 7;
}
```

### gRPC Performance Best Practices

| Practice | Mô tả |
|----------|--------|
| Connection pooling | Reuse connections, không tạo mới cho mỗi request |
| Deadline propagation | Set timeout cho mỗi call, tránh request treo vĩnh viễn |
| Load balancing | Client-side LB với round-robin hoặc least-connections |
| Retry policy | Tự động retry với exponential backoff cho transient errors |
| Health check | gRPC health checking protocol để detect unhealthy instances |

---

## So sánh tổng quan

| Tiêu chí | MQTT | WebSocket | gRPC |
|----------|------|-----------|------|
| **Dùng cho** | Driver ↔ Server | Rider ↔ Server | Service ↔ Service |
| **Protocol** | TCP (lightweight) | TCP (HTTP upgrade) | HTTP/2 |
| **Payload** | Binary/JSON | JSON | Protocol Buffers |
| **Offline support** | ✅ QoS + Session | ❌ (reconnect) | ❌ |
| **Latency** | Rất thấp | Thấp | Cực thấp |
| **Bandwidth** | Cực ít (2 bytes header) | Trung bình | Ít |
| **Mạng yếu** | ✅ Xuất sắc | ⚠️ Tạm được | ❌ Không phù hợp |
