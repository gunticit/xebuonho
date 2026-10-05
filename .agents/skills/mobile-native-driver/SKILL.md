---
name: Native Mobile - Driver App
description: Hướng dẫn phát triển Driver App native (Kotlin/Swift) với background location, MQTT, và offline-first.
---

# Native Mobile - Driver App

## Khi nào dùng skill này?
- Phát triển hoặc debug Driver App
- Xử lý background location tracking
- Implement offline queue và MQTT communication

## Tại sao Native?
- **Background location**: Chạy liên tục 8-10h/ngày
- **OS integration**: Foreground Service (Android), Background Task (iOS)
- **Battery optimization**: Fine-tune GPS frequency
- **Chống kill app**: `START_STICKY`, foreground notification

## Architecture
```
UI Layer → ViewModel → Service Layer → Platform Layer
                ↕              ↕
           Local DB      MQTT/REST
         (Room/CoreData)  (Network)
```

## Critical Components
1. **LocationForegroundService** (Android): Giữ GPS chạy ngầm
2. **OfflineQueueManager**: Lưu actions khi mất mạng
3. **MQTTConnectionManager**: Quản lý kết nối MQTT
4. **TripStateMachine**: State management cho chuyến xe

## GPS Frequency Strategy
| State | Interval | Accuracy |
|-------|----------|----------|
| WAITING | 10s | BALANCED |
| APPROACHING | 3s | HIGH |
| IN_TRIP | 2s | HIGH |
| OFFLINE | OFF | - |

---

## Anti-Fraud & Driver Security Guardrails

### 1. Phát Hiện Mock GPS & Thiết Bị Can Thiệp (Anti-Mock & Root Detection)
- **Kiểm tra Mock Location Provider (Android)**:
  ```kotlin
  fun isLocationSpoofed(location: Location): Boolean {
      return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
          location.isMock
      } else {
          location.isFromMockProvider
      }
  }
  ```
- **Kiểm tra Root & Hooking Frameworks**:
  Kiểm tra sự hiện diện của `su binary`, Magisk, Frida, Xposed framework. Nếu phát hiện bị can thiệp bộ nhớ hoặc tiêm mã, tự động đưa tài khoản vào danh sách nghi vấn và tạm dừng gán cuốc xe tự động.

### 2. Ký Số Gói Tin Tọa Độ (Telemetry Integrity)
Mỗi tọa độ gửi lên qua MQTT/HTTP mang theo:
- `timestamp`: Thời gian sinh tại phần cứng GPS (ngăn chặn replay attack).
- `sequence_id`: Số thứ tự tăng dần.
- `signature`: HMAC-SHA256(`lat|lng|timestamp|sequence_id`, `device_hardware_secret`).
Server sẽ loại bỏ các gói tin có timestamp lệch quá 60 giây hoặc sequence_id bị đảo lộn bất thường.

### 3. Tối Ưu Pin & Chống Tắt Ứng Dụng (Battery & Lifecycle)
- Sử dụng Foreground Service với thông báo Notification có mức độ ưu tiên `IMPORTANCE_LOW` để không làm phiền tài xế nhưng tránh bị hệ thống Android dọn dẹp (Low Memory Killer).
- Khi xe dừng đèn đỏ hoặc đứng yên > 3 phút (dựa vào cảm biến gia tốc kế Accelerometer), tự động giãn chu kỳ quét GPS từ 2s lên 10s để tiết kiệm pin.

---

## References
- Architecture: [docs/architecture/MOBILE-APPS.md](../../docs/architecture/MOBILE-APPS.md)
- Offline-First: [docs/best-practices/OFFLINE-FIRST.md](../../docs/best-practices/OFFLINE-FIRST.md)
- Dual Role System: [skills/dual-role-system/SKILL.md](../dual-role-system/SKILL.md)
- Security & Anti-Fraud: [skills/security-anti-fraud/SKILL.md](../security-anti-fraud/SKILL.md)

