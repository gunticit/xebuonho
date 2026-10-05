---
name: Cross-platform Mobile - Rider App
description: Hướng dẫn phát triển Rider App bằng Flutter/React Native với WebSocket, maps, và payment.
---

# Cross-platform Mobile - Rider App

## Khi nào dùng skill này?
- Phát triển Rider App (Flutter hoặc React Native)
- Implement live tracking, booking flow, chat
- Integrate maps SDK và payment

## Tech Options
| Framework | Pros | Cons |
|-----------|------|------|
| **Flutter** | Dart, hot reload, beautiful UI | Smaller ecosystem |
| **React Native** | JS/TS ecosystem, large community | Bridge overhead |

## Key Features
1. **Home**: Map + search destination + book ride
2. **Live Tracking**: Watch driver move on map realtime
3. **Chat**: In-app messaging with driver
4. **Payment**: Cash, Wallet, MoMo, ZaloPay
5. **Trip History**: Past rides, ratings, receipts

## WebSocket Integration
```dart
// Flutter Socket.io
final socket = IO.io('wss://api.xebuonho.vn/rides', 
  IO.OptionBuilder()
    .setTransports(['websocket'])
    .setAuth({'token': jwt})
    .build());

socket.on('driver:location', (data) => updateDriverMarker(data));
socket.on('ride:status', (data) => updateRideStatus(data));
```

## State Management
- **Flutter**: BLoC, Riverpod, or Provider
- **React Native**: Redux Toolkit or Zustand

---

## Client Security & Anti-Fraud Best Practices

### 1. Lưu Trữ Token An Toàn (Secure Token Storage)
- **TUYỆT ĐỐI KHÔNG LƯU JWT VÀO `SharedPreferences` HOẶC `localStorage`** (dễ bị trích xuất nếu máy bị root/jailbreak).
- Sử dụng `flutter_secure_storage`:
  - iOS: Lưu trong **Keychain Services** với cờ `kSecAttrAccessibleAfterFirstUnlock`.
  - Android: Mã hóa bằng **EncryptedSharedPreferences** với khóa trong **Android Keystore**.

### 2. Tự Động Sinh `X-Idempotency-Key`
Mọi thao tác tạo đơn hoặc thanh toán phải gắn UUID duy nhất để tránh việc người dùng bấm liên tục gây tạo nhiều cuốc xe:
```dart
final idempotencyKey = 'ride-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
dio.options.headers['X-Idempotency-Key'] = idempotencyKey;
```

### 3. Tự Động Làm Mới Token (Silent Refresh Interceptor)
Bắt mã lỗi `401 Unauthorized` tại Dio Interceptor, tự động gọi `/api/v1/auth/refresh` bằng refresh token được mã hóa và retry lại request cũ một cách mượt mà mà không đẩy khách ra màn hình đăng nhập.

### 4. Che Giấu Dữ Liệu Nhạy Cảm (PII Masking)
- Không in (log) số điện thoại, email, hoặc chuỗi JWT đầy đủ ra console bằng `print()` khi chạy bản release.
- Bật cờ `kReleaseMode` để tự động tắt HTTP Logger.

---

## References
- Architecture: [docs/architecture/MOBILE-APPS.md](../../docs/architecture/MOBILE-APPS.md)
- Dual Role System: [skills/dual-role-system/SKILL.md](../dual-role-system/SKILL.md)
- Security & Anti-Fraud: [skills/security-anti-fraud/SKILL.md](../security-anti-fraud/SKILL.md)

