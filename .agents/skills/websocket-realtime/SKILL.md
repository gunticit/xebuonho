---
name: WebSocket Real-time (Socket.io)
description: Hướng dẫn triển khai WebSocket/Socket.io cho Rider App - push notifications, live tracking, chat.
---

# WebSocket Real-time (Socket.io)

## Khi nào dùng skill này?
- Triển khai live tracking cho Rider App (vẽ xe di chuyển trên bản đồ)
- Push notifications realtime (tài xế đang đến, tin nhắn)
- In-app chat giữa tài xế và khách

## Tech Stack
- **Server**: `socket.io` (Node.js) hoặc Go adapter
- **Client (Flutter)**: `socket_io_client`
- **Client (React Native)**: `socket.io-client`

## Events Reference

### Server → Client
| Event | Data | Mô tả |
|-------|------|--------|
| `driver:location` | `{lat, lng, heading, eta}` | Vị trí tài xế realtime |
| `ride:status` | `{status, message}` | Trạng thái cuốc xe |
| `chat:message` | `{from, text, timestamp}` | Tin nhắn từ tài xế |
| `fare:update` | `{amount, reason}` | Cập nhật giá |

### Client → Server
| Event | Data | Mô tả |
|-------|------|--------|
| `subscribe:ride` | `rideId` | Subscribe theo dõi cuốc |
| `unsubscribe:ride` | `rideId` | Hủy theo dõi |
| `chat:send` | `{rideId, text}` | Gửi tin nhắn |

## Connection Setup
```javascript
const socket = io('wss://api.xebuonho.vn/rides', {
  transports: ['websocket'],
  auth: { token: jwtToken },
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
});
```

## References
- Xem chi tiết: [docs/architecture/COMMUNICATION.md](../../docs/architecture/COMMUNICATION.md)
