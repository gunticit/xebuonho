---
name: WebSocket Real-time & Live Tracking
description: Hướng dẫn triển khai WebSocket cho ứng dụng Khách hàng (Rider App) - push notifications, live tracking xe di chuyển, chat trực tiếp và quản lý phòng (Rooms).
---

# WebSocket Real-time & Live Tracking Architecture

## 1. Khi nào dùng skill này?
- Triển khai **Live Tracking** cho Rider App (vẽ icon xe di chuyển mượt mà trên bản đồ theo tọa độ GPS của tài xế).
- Đẩy thông báo thời gian thực (**Push Notifications**) khi cuốc xe chuyển trạng thái (`accepted` -> `arrived` -> `in_progress` -> `completed`).
- Tính năng **In-app Chat** trực tiếp giữa Khách hàng và Tài xế trong chuyến đi.
- Quản lý kết nối, xác thực token JWT lúc Handshake, và heartbeat ping/pong chống ngắt kết nối ảo (Ghost Connections).

---

## 2. Kiến Trúc Luồng Sự Kiện & Quản Lý Phòng (Room-based Dispatch)

Thay vì broadcast toàn server, WebSocket Hub quản lý theo các **Room** theo mã chuyến đi (`trip:<order_id>`) hoặc theo mã người dùng (`user:<user_id>`).

```
                    ┌───────────────────────────┐
                    │     API Gateway Hub       │
                    │ (services/api-gateway/ws) │
                    └─────────────┬─────────────┘
                                  │
         ┌────────────────────────┴────────────────────────┐
         │ Room: "trip:order-uuid-123"                    │
         │  - Thành viên: Rider A, Driver B, Admin Ops    │
         └─────────────┬─────────────────────┬────────────┘
                       │                     │
                       ▼                     ▼
              [Rider App Flutter]   [Driver Web/Native]
```

---

## 3. Quy Ước Sự Kiện (Events Protocol)

### 3.1. Client ──▶ Server
| Event | Payload | Mô tả |
|---|---|---|
| `auth` | `{ token: "jwt..." }` | Gửi xác thực ngay sau khi kết nối nếu không truyền qua Query param |
| `join_trip` | `{ trip_id: "uuid" }` | Đăng ký lắng nghe sự kiện của chuyến xe cụ thể |
| `leave_trip` | `{ trip_id: "uuid" }` | Hủy đăng ký khi chuyến xe hoàn tất hoặc đóng màn hình |
| `chat_message` | `{ trip_id: "uuid", message: "text", type: "text" }` | Gửi tin nhắn cho đối phương trong chuyến đi |
| `ping` | `{ timestamp: 1234567890 }` | Heartbeat giữ kết nối sống (chu kỳ 25 giây) |

### 3.2. Server ──▶ Client
| Event | Payload | Mô tả |
|---|---|---|
| `driver_location` | `{ trip_id, lat, lng, bearing, speed, eta_min }` | Tọa độ tài xế để vẽ xe di chuyển trên bản đồ |
| `trip_status_changed` | `{ trip_id, status, action, message, timestamp }` | Cập nhật bước đi của tài xế (Đã đến, Đã đón...) |
| `chat_received` | `{ trip_id, sender_id, sender_name, message, time }` | Tin nhắn mới nhận được trong chuyến đi |
| `pong` | `{ timestamp: 1234567890 }` | Phản hồi xác nhận kết nối ổn định |

---

## 4. Bảo Mật & Xác Thực (Security & Anti-Ghost)

### 4.1. Xác thực lúc Handshake
Kết nối WebSocket bắt buộc mang theo JWT token hợp lệ:
```
wss://api.xebuonho.vn/ws?token=eyJhbGciOi...
```
Hoặc qua HTTP Header `Sec-WebSocket-Protocol: Bearer, <token>`.
Server từ chối nâng cấp HTTP sang WebSocket (HTTP 401) nếu token không hợp lệ hoặc đã bị thu hồi trong Redis.

### 4.2. Chống Kết Nối Ảo (Ghost Connection Cleanup)
- Thiết lập Ping/Pong chu kỳ: Client gửi `ping` mỗi 25s; Nếu sau 60s Server không nhận được gói tin nào từ Client, tự động đóng kết nối (`conn.Close()`) và giải phóng tài nguyên Hub.

### 4.3. Quyền Riêng Tư Tin Nhắn Chat (Ephemeral Messaging)
- Chỉ Rider và Driver được phân công trong đơn hàng mới có quyền join vào room `trip:<id>`.
- Mọi tin nhắn trao đổi trong chuyến đi chỉ được lưu trữ tạm thời; tự động đánh dấu lưu trữ sau khi cuốc xe kết thúc 24 giờ nhằm bảo vệ thông tin riêng tư (PII).

---

## 5. Triển Khai Trong Mã Nguồn Dự Án

### 5.1. Backend Go:
- Thư mục: [`services/api-gateway/internal/ws/`](../../services/api-gateway/internal/ws/)
- Hub quản lý kết nối: `hub.go`
- Nâng cấp HTTP sang WebSocket: `gorilla/websocket`

### 5.2. Flutter Client (`apps/rider`):
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeTrackingService {
  late WebSocketChannel _channel;

  void connect(String token, String tripId) {
    final uri = Uri.parse('wss://api.xebuonho.vn/ws?token=$token');
    _channel = WebSocketChannel.connect(uri);
    
    // Gửi lệnh tham gia phòng
    _channel.sink.add(jsonEncode({
      'event': 'join_trip',
      'data': {'trip_id': tripId}
    }));
    
    // Lắng nghe tọa độ
    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['event'] == 'driver_location') {
        _updateMarkerPosition(data['lat'], data['lng'], data['bearing']);
      }
    });
  }
}
```

---

## 6. References
- Kiến trúc truyền thông: [`docs/architecture/COMMUNICATION.md`](../../docs/architecture/COMMUNICATION.md)
- Phía tài xế (MQTT): [`skills/mqtt-realtime/SKILL.md`](../mqtt-realtime/SKILL.md)
- Gateway router: [`services/api-gateway/internal/router/router.go`](../../services/api-gateway/internal/router/router.go)
