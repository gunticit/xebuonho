# 🏍️ Xebuonho Rider App

Ứng dụng Flutter cho khách hàng — đặt xe (xe máy/ô tô), đặt đồ ăn, chia bill, thanh toán SePay/VietQR, theo dõi chuyến realtime.

> Là client của microservices Go ở `services/*`. Có **demo mode**: nếu backend chưa chạy, app vẫn hoạt động với dữ liệu giả.

---

## 🚀 Chạy thử

```bash
# Trong thư mục apps/rider
flutter pub get

# Web (Chrome)
flutter run -d chrome

# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android
```

Yêu cầu Flutter `>=3.2.0 <4.0.0`. Backend service xem hướng dẫn ở `../../README.md`.

---

## 🧭 Cấu trúc thư mục

```
lib/
├── main.dart                       # MultiProvider + 26 routes
├── config/
│   ├── theme.dart                  # Dark theme + AppColors
│   └── api_config.dart             # Endpoint API gateway
├── models/
│   ├── app_models.dart             # Restaurant, MenuItem, CartItem, FoodOrder, ShareBillMember
│   ├── ride.dart                   # RideModel, VehicleType, RideStatus
│   ├── driver.dart
│   └── location.dart
├── providers/                      # ChangeNotifier (Provider)
│   ├── auth_provider.dart          # JWT, OTP, persisted via SharedPreferences
│   ├── booking_provider.dart       # State machine đặt xe
│   └── location_provider.dart      # Geolocator
├── services/
│   ├── api_service.dart            # Dio client + JWT interceptor
│   ├── geocoding_service.dart      # Nominatim (OSM)
│   ├── location_service.dart
│   └── sepay_service.dart          # VietQR + polling check thanh toán
├── screens/
│   ├── splash_screen.dart          # Consent dialog lần đầu mở
│   ├── onboarding_screen.dart      # 3-slide intro
│   ├── login_screen.dart / otp_screen.dart
│   ├── home_screen.dart            # Bản đồ + dịch vụ
│   ├── search_screen.dart          # Tìm + gợi ý địa chỉ
│   ├── booking_screen.dart         # Chọn xe, ước tính giá
│   ├── tracking_screen.dart        # Theo dõi realtime
│   ├── trip_complete_screen.dart   # Đánh giá tài xế
│   ├── ride_detail_screen.dart
│   ├── chat_screen.dart            # Chat + Report/Block
│   ├── history_screen.dart         # Tab Tất cả / Xe / Đồ ăn
│   ├── profile_screen.dart / settings_screen.dart
│   ├── payment_screen.dart / top_up_screen.dart
│   ├── promotions_screen.dart / notifications_screen.dart
│   ├── support_screen.dart / saved_addresses_screen.dart
│   ├── legal_screens.dart          # Privacy + Terms
│   └── food/
│       ├── restaurant_list_screen.dart
│       ├── restaurant_detail_screen.dart   # Nhận args: Restaurant
│       ├── checkout_screen.dart            # Nhận args: cart + restaurant info
│       ├── sepay_payment_screen.dart       # VietQR + polling
│       ├── order_tracking_screen.dart      # Timeline + rating dialog khi giao xong
│       ├── order_detail_screen.dart        # Nhận args order hoặc fallback demo
│       └── share_bill_screen.dart          # Chia đều / theo món / tùy chỉnh
└── widgets/
    ├── app_drawer.dart
    ├── consent_dialog.dart         # GDPR consent
    └── sos_schedule.dart
```

---

## 🛣️ Routes (main.dart)

| Group | Routes |
|-------|--------|
| Core | `/`, `/onboarding`, `/login`, `/otp`, `/home` |
| Ride | `/search`, `/booking`, `/tracking`, `/complete`, `/ride-detail` |
| Account | `/profile`, `/payment`, `/top-up`, `/promotions`, `/notifications`, `/support`, `/settings`, `/history`, `/saved-addresses`, `/chat` |
| Legal | `/privacy`, `/terms` |
| Food | `/food`, `/restaurant-detail`, `/checkout`, `/sepay-payment`, `/order-tracking`, `/order-detail`, `/share-bill` |

---

## 🔑 Tính năng chính

### Đặt xe
- 3 loại xe: bike, car, premium — fare estimate qua API hoặc fallback Haversine
- State machine: `idle → selectingDestination → selectingVehicle → estimating → confirming → searching → driverFound → tracking → completed`
- Live tracking với `flutter_map` + CartoDB dark tile
- Chat với tài xế, report/block, SOS

### Đặt đồ ăn
- Danh sách nhà hàng + filter theo category, search
- Menu nhiều nhóm, giỏ hàng (CartItem) với +/- quantity
- Checkout: chọn địa chỉ, mã giảm giá, ghi chú, 5 phương thức thanh toán
- **Theo dõi đơn**: timeline 5 bước (placed → confirmed → preparing → pickedUp → delivering)
- **Rating dialog** khi đơn giao xong (5 sao + tags)
- **Chia bill**: chia đều / theo món / tùy chỉnh + share Zalo/SMS/copy link

### Thanh toán SePay (VietQR)
- Generate QR theo `https://qr.sepay.vn/img?bank=...&amount=...&des=ORDER_ID`
- Đếm ngược 5 phút
- Polling `/transactions/list` mỗi 5s để xác nhận tự động
- Fallback chuyển khoản thủ công với copy ngân hàng / số TK / nội dung

### Auth
- Login bằng số điện thoại + OTP
- JWT lưu trong `SharedPreferences`, auto-attach qua Dio interceptor
- Demo mode khi backend chưa chạy

---

## 🎨 Design system

`config/theme.dart` — dark theme, dùng GoogleFonts Inter. Bảng màu trong `AppColors`:

| Token | Mô tả |
|-------|-------|
| `bg`, `bg2`, `bg3` | 3 cấp nền tối |
| `text`, `text2`, `text3` | 3 cấp typography |
| `green/blue/orange/purple/red/cyan` + `*Bg` | Accent + variant nền nhạt |

---

## 📦 Dependencies

```yaml
flutter_map: ^6.1.0          # Bản đồ
latlong2: ^0.9.0
geolocator: ^11.0.0          # GPS
dio: ^5.4.0                  # HTTP
provider: ^6.1.1             # State
google_fonts: ^6.1.0
shimmer: ^3.0.0              # Loading skeleton
intl: ^0.19.0                # NumberFormat VND
flutter_rating_bar: ^4.0.1
cached_network_image: ^3.3.1
shared_preferences: ^2.2.2
```

---

## 🧪 Test

```bash
flutter test
flutter analyze              # Lint
```

---

## 🔗 Backend liên quan

App gọi qua `api-gateway:8000`. Auth gọi trực tiếp `user-service:8091` để bypass middleware. Xem `config/api_config.dart` và `services/api_service.dart`.

| Endpoint | Service |
|----------|---------|
| `POST /auth/login`, `verify-otp` | user-service |
| `POST /rides/estimate`, `POST /rides` | ride-service (qua gateway) |
| `GET /merchants/nearby` | merchant-service |
| `GET /driver/location/nearby` | location-service |
