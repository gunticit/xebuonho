---
name: MQTT Real-time Communication
description: Hướng dẫn triển khai MQTT broker (EMQX) cho giao tiếp tài xế-server với QoS đảm bảo không mất dữ liệu.
---

# MQTT Real-time Communication

## Khi nào dùng skill này?
- Triển khai giao tiếp giữa Driver App và Backend
- Cần đảm bảo message delivery trên mạng di động yếu
- Xử lý GPS location streaming từ tài xế

## Tech Stack
- **Broker**: EMQX 5.x (hoặc HiveMQ)
- **Client (Go)**: `github.com/eclipse/paho.mqtt.golang`
- **Client (Android)**: `org.eclipse.paho:org.eclipse.paho.client.mqttv3`
- **Client (iOS)**: `CocoaMQTT`

## Setup EMQX Broker

```bash
# Docker
docker run -d --name emqx \
  -p 1883:1883 -p 8083:8083 -p 8084:8084 -p 8883:8883 -p 18083:18083 \
  emqx/emqx:5.4.0

# Dashboard: http://localhost:18083 (admin/public)
```

## MQTT Topics Convention
```
drivers/{driver_id}/location          # QoS 1 - GPS updates
drivers/{driver_id}/status            # QoS 2 - Online/Offline
drivers/{driver_id}/rides/request     # QoS 2 - Ride notification
drivers/{driver_id}/rides/response    # QoS 2 - Accept/Reject
trips/{trip_id}/status                # QoS 2 - Trip status
```

## QoS Selection Guide
- **QoS 0**: Non-critical data (analytics, heartbeat)
- **QoS 1**: Location updates (gửi ít nhất 1 lần, ok nếu duplicate)
- **QoS 2**: Ride actions, status changes (exactly once, critical)

## Key Configuration
- `CleanSession: false` → Giữ session khi reconnect
- `AutoReconnect: true` → Tự kết nối lại
- `KeepAlive: 30s` → Heartbeat interval
- `SessionExpiryInterval: 7200` → Giữ session 2 giờ

## References
- Xem chi tiết: [docs/architecture/COMMUNICATION.md](../../docs/architecture/COMMUNICATION.md)
- Code example: [pkg/mqtt/](../../pkg/mqtt/)
