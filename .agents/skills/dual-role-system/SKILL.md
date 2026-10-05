---
name: Dual Role Architecture - Rider & Driver
description: Hướng dẫn kiến trúc đa vai trò (Khách hàng & Tài xế) trong Flutter, cơ chế module hóa độc lập, state management, và lộ trình tách thành standalone Driver App.
---

# Dual Role Architecture - Rider & Driver

## 1. Khi nào dùng skill này?
- Cần hiểu hoặc mở rộng logic cho Khách hàng (Rider) hoặc Tài xế (Driver).
- Thêm tính năng mới cho Dashboard tài xế: nhận cuốc, định vị, cập nhật chuyến đi, thu nhập, lịch sử.
- Triển khai tách module Tài xế thành ứng dụng độc lập (`apps/driver`).
- Tích hợp thêm các nghiệp vụ đặc thù: Giao đồ ăn (Food), Đi chợ hộ (Grocery), Lái xe hộ (Designated Driver).

---

## 2. Kiến trúc Dual Role hiện tại (Monorepo Flutter)

Để thuận tiện phát triển ban đầu, ứng dụng Flutter tại `apps/rider` hỗ trợ cả 2 vai trò với tính năng chuyển đổi 1-chạm (1-click role switch), nhưng **toàn bộ mã nguồn tài xế được module hóa hoàn toàn độc lập**:

```
apps/rider/lib/
├── models/
│   ├── driver_models.dart       # Domain models riêng cho Driver (DriverStatus, DriverTrip, DriverRideRequest, DriverDailyStats)
│   ├── ride.dart                # Shared Ride models (ServiceType, VehicleType)
│   └── user.dart                # User model chứa role: rider | driver | merchant | admin
├── providers/
│   ├── driver_provider.dart     # State management độc lập cho Tài xế (Online/Offline, Poll orders, Accept, Progress trip)
│   ├── auth_provider.dart       # Quản lý phiên đăng nhập, JWT token, role hiện tại
│   └── active_order_provider.dart # State chuyến đi phía Khách hàng
├── screens/
│   ├── driver/                  # Toàn bộ UI dành cho Tài xế
│   │   ├── driver_dashboard_screen.dart # Radar radar trạng thái, điểm nóng thưởng, nhận cuốc, chế độ dẫn đường
│   │   └── driver_history_screen.dart   # Lịch sử cuốc xe và thu nhập
│   ├── booking_screen.dart      # Đặt xe phía Khách
│   └── login_screen.dart        # Đăng nhập 1-chạm: [🙋‍♂️ Khách (Demo)] & [🚕 Tài xế (Demo)]
└── widgets/
    └── app_drawer.dart          # Banner chuyển đổi vai trò (Switch to Driver / Switch to Rider)
```

---

## 3. Quản lý trạng thái Tài xế (`DriverProvider`)

File: [`apps/rider/lib/providers/driver_provider.dart`](file:///Users/hwg/Documents/xebuonho/apps/rider/lib/providers/driver_provider.dart)

### Vòng đời trạng thái tài xế:
1. **`offline`**: Tài xế nghỉ ngơi, không nhận yêu cầu cuốc xe.
2. **`online`**: Tài xế bật trạng thái sẵn sàng. Hệ thống bắt đầu:
   - Polling danh sách cuốc xe chờ (`orders.status = 'created'`) từ PostgreSQL qua `ApiService().getDriverRequests()` mỗi 4 giây.
   - Khi có cuốc xe, hiển thị Modal nhận cuốc kèm đếm ngược 15 giây (`_incomingCountdown`).
3. **`busy` / `on_trip`**: Tài xế chấp nhận cuốc xe (`acceptIncomingRide()`), gửi API `POST /api/v1/driver/accept`.
   - Vòng đời chuyến đi:
     - `accepted` (Đã nhận cuốc)
     - `arrivingPickup` (Đang tới điểm đón)
     - `arrivedPickup` (Đã tới điểm đón) -> `POST /api/v1/driver/trip/update` (action: `arrived`)
     - `inProgress` (Đang di chuyển cùng khách) -> `POST /api/v1/driver/trip/update` (action: `picked_up`)
     - `completed` (Hoàn thành) -> `POST /api/v1/driver/trip/update` (action: `completed`), cộng tiền vào `todayEarnings`
     - `cancelled` (Hủy) -> `POST /api/v1/driver/trip/update` (action: `cancelled`)

---

## 4. Tài khoản Demo sẵn có trong Database thật

Dữ liệu được seed sẵn trong PostgreSQL (`migrations/seed_real_data.sql`):

| Vai trò | Số điện thoại | Mật khẩu | User ID | Xe / Ghi chú |
|---|---|---|---|---|
| **Khách hàng** | `0901234567` | `password123` | `ca3065df-b201-4e92-a807-04b51354a8d3` | Khách VIP, rating 5.0 |
| **Tài xế** | `0912345678` | `secret123` | `93623b04-ecc7-4654-8846-e05f72ab8069` | Toyota Vios 2023, BKS `59-E1 888.66`, full 4 dịch vụ |

---

## 5. Hướng dẫn trích xuất thành Standalone Driver App (`apps/driver`)

Khi doanh nghiệp muốn phát hành riêng ứng dụng Driver trên Google Play / App Store:

1. **Khởi tạo thư mục ứng dụng**:
   ```bash
   cp -r apps/rider apps/driver
   ```
2. **Di chuyển các file lõi**:
   - `lib/models/driver_models.dart` -> trở thành domain model chính.
   - `lib/providers/driver_provider.dart` -> provider trung tâm.
   - `lib/screens/driver/driver_dashboard_screen.dart` -> màn hình chính (`HomeScreen`).
   - `lib/screens/driver/driver_history_screen.dart` -> màn hình lịch sử.
3. **Cập nhật `main.dart`**:
   - `initialRoute: '/dashboard'` trỏ trực tiếp đến `DriverDashboardScreen`.
   - Bỏ các màn hình Khách hàng (`booking_screen`, `food_screen`, `activity_screen`).
4. **Cấu hình Native & Background Location**:
   - Android: Thêm Foreground Service với `ACCESS_FINE_LOCATION` và `ACCESS_BACKGROUND_LOCATION`.
   - iOS: Thêm Background Modes `Location updates`.
   - Xem chi tiết tại skill `mobile-native-driver`.
