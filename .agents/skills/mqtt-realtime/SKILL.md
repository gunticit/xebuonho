---
name: MQTT Real-time Communication & Telemetry
description: Hướng dẫn triển khai MQTT broker (EMQX) cho giao tiếp tài xế-server với QoS đảm bảo, phân quyền ACL theo Client ID, và chữ ký số telemetry.
---

# MQTT Real-time Communication & Telemetry Guide

## 1. Khi nào dùng skill này?
- Triển khai kênh truyền thông hai chiều giữa **Driver App (Tài xế)** và **Backend Microservices**.
- Truyền phát liên tục tọa độ GPS (Telemetry Streaming) trên mạng di động 3G/4G chập chờn, tiết kiệm pin và băng thông.
- Đảm bảo 100% không mất cuốc xe khi tài xế đi vào vùng mất sóng (QoS 2 và Session Persistence).
- Thiết lập phân quyền truy cập (ACL) và xác thực (Authentication) trên broker EMQX.

---

## 2. Kiến Trúc Broker EMQX & Phân Tách Giao Thức

Hệ thống Xebuonho phân định ranh giới rõ ràng giữa hai đối tượng người dùng:
- **Khách hàng (Rider)**: Sử dụng **WebSocket** (qua API Gateway port 8000) vì ứng dụng chủ yếu chạy khi mở màn hình.
- **Tài xế (Driver)**: Sử dụng **MQTT qua TCP (Port 1883 / TLS 8883)** vì cần giữ kết nối ngầm (Background Service) 8-12 tiếng liên tục với chi phí gói tin cực nhẹ (2 bytes header).

```
[Driver Android/iOS/Web]
        │
        ▼ (MQTT TCP port 1883 / TLS 8883)
┌────────────────────────────────────────┐
│         EMQX Broker Cluster            │
│  - Dashboard: http://localhost:18083   │
│  - Rule Engine ──▶ Webhook/Kafka/Redis │
└───────────────────┬────────────────────┘
                    │
                    ▼ (gRPC / Kafka)
         ┌─────────────────────┐
         │   driver-service    │
         │  location-service   │
         └─────────────────────┘
```

---

## 3. Quy Ước Topic Hierarchy & Ma Trận QoS

### 3.1. Danh mục Topics:
```
drivers/{driver_id}/location          # QoS 1 - Tọa độ GPS định kỳ (2-5s)
drivers/{driver_id}/status            # QoS 2 - Chuyển Online / Offline
drivers/{driver_id}/rides/request     # QoS 2 - Server bắn cuốc xe mới tới tài xế
drivers/{driver_id}/rides/response    # QoS 2 - Tài xế bấm Nhận / Từ chối
trips/{trip_id}/status                # QoS 2 - Cập nhật bước đi (Arrived, PickedUp, Completed)
drivers/{driver_id}/sos               # QoS 2 - Báo động khẩn cấp SOS
```

### 3.2. Ma Trận Chất Lượng Dịch Vụ (QoS Policy):
- **QoS 0 (At most once)**: Thống kê mạng, đo ping, thông tin pin thiết bị.
- **QoS 1 (At least once)**: Tọa độ GPS. Chấp nhận trùng lặp nhẹ vì điểm sau sẽ ghi đè điểm trước trong Redis GEO.
- **QoS 2 (Exactly once)**: Phát cuốc xe, xác nhận nhận cuốc, kết thúc chuyến và trừ tiền ví. **BẮT BUỘC** đến đúng 1 lần duy nhất, không được mất và không được lặp.

---

## 4. Bảo Mật & Phân Quyền ACL (Access Control Lists)

Tránh lỗ hổng bảo mật tài xế này giả mạo gửi tọa độ của tài xế khác hoặc nghe lén cuốc xe của đối thủ:

### 4.1. Quy tắc EMQX ACL:
```hocon
# Cho phép tài xế chỉ được publish/subscribe đúng topic có chứa driver_id của chính mình
{allow, {username, "^driver_(.+)$"}, publish, ["drivers/${username}/#", "trips/#"]}.
{allow, {username, "^driver_(.+)$"}, subscribe, ["drivers/${username}/#", "trips/#"]}.
{deny, all}.
```

### 4.2. Ký số gói tin Telemetry chống Replay Attack:
Mỗi gói tin JSON gửi lên `drivers/{id}/location` gồm:
```json
{
  "lat": 10.7769,
  "lng": 106.7009,
  "speed": 35.5,
  "bearing": 180.0,
  "seq": 1042,
  "timestamp": 1728567890,
  "sig": "hmac_sha256_hash"
}
```

---

## 5. Cấu Hình Session & Khả Năng Chịu Lỗi (Offline-First)

Khi tài xế đi vào hầm chung cư hoặc mất sóng 4G:
- `CleanSession: false` (MQTT v3.1.1) hoặc `CleanStart: false` (MQTT v5.0): Giữ nguyên hàng đợi tin nhắn trên broker.
- `SessionExpiryInterval: 7200` (giữ session 2 tiếng).
- **Trên Driver Mobile**: Tích hợp hàng đợi ngoại tuyến (`OfflineQueueManager`). Mọi hành động bấm nút của tài xế được ghi tạm vào SQLite/Room local; ngay khi có mạng trở lại, client tự động đẩy các tin nhắn tồn đọng lên server theo đúng thứ tự `seq`.

---

## 6. Khởi Động & Quản Trị EMQX Trong Dự Án
```bash
# Docker Compose đã tích hợp sẵn:
docker compose up -d emqx

# Truy cập Dashboard quản trị EMQX:
URL: http://localhost:18083
Tài khoản mặc định: admin
Mật khẩu mặc định: public (yêu cầu đổi mật khẩu ở lần đăng nhập đầu)
```

---

## 7. References
- Kiến trúc truyền thông: [`docs/architecture/COMMUNICATION.md`](../../docs/architecture/COMMUNICATION.md)
- Nguyên lý Offline-first: [`docs/best-practices/OFFLINE-FIRST.md`](../../docs/best-practices/OFFLINE-FIRST.md)
- Mã nguồn Go MQTT: [`pkg/mqtt/`](../../pkg/mqtt/)
- Skill Driver Mobile: [`skills/mobile-native-driver/SKILL.md`](../mobile-native-driver/SKILL.md)
