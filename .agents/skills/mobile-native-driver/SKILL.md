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

## References
- Architecture: [docs/architecture/MOBILE-APPS.md](../../docs/architecture/MOBILE-APPS.md)
- Offline-First: [docs/best-practices/OFFLINE-FIRST.md](../../docs/best-practices/OFFLINE-FIRST.md)
