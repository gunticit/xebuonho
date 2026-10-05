# Hướng Dẫn Phát Triển & Mở Rộng Dự Án Xebuonho (AI Developer Guide)

Tài liệu này được biên soạn đặc biệt dành cho các kỹ sư phần mềm và các trợ lý AI (Gemini, Claude, GPT, Antigravity Agent) nhằm nắm bắt nhanh toàn bộ kiến trúc, quy chuẩn mã nguồn, cách vận hành, và các hướng dẫn mở rộng tương lai cho nền tảng **Xebuonho**.

---

## 1. Tổng Quan Kiến Trúc (Architecture Overview)

Xebuonho là nền tảng gọi xe và giao hàng đa dịch vụ (Super App) bao gồm:
1. **Frontend**: Ứng dụng Flutter đa nền tảng (`apps/rider`) hỗ trợ đồng thời cả vai trò **Khách hàng (Rider)** và **Tài xế (Driver)** với cơ chế tách biệt module hoàn chỉnh.
2. **Backend**: Hệ thống Microservices viết bằng **Go (Golang)** chuẩn production (`go.work`), kết nối qua HTTP REST và gRPC nội bộ.
3. **Database & Storage**:
   - **PostgreSQL 16 + PostGIS**: Lưu trữ dữ liệu quan hệ và vị trí địa lý thực tế (`ST_DWithin`, `ST_Distance`).
   - **Redis 7**: Caching và Geospatial index cho vị trí realtime của tài xế (`GEOADD`, `GEORADIUS`).
   - **Apache Kafka**: Event streaming xử lý luồng sự kiện bất đồng bộ.
   - **EMQX MQTT Broker**: Giao tiếp tài xế - server thời gian thực.

```
                      ┌────────────────────────────────────────┐
                      │          Flutter Multi-Platform        │
                      │  [🙋‍♂️ Khách hàng]   ───   [🚕 Tài xế]  │
                      └───────────────────┬────────────────────┘
                                          │ HTTP / REST
                                          ▼
                      ┌────────────────────────────────────────┐
                      │          API Gateway (:8000)           │
                      │  - JWT Authentication                  │
                      │  - Direct PostGIS Spatial Queries      │
                      │  - Reverse Proxy to Microservices      │
                      └───────┬──────────────┬───────────────┬─┘
                              │              │               │
                              ▼              ▼               ▼
                      ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
                      │ user-service │ │ ride-service │ │merchant-serv │
                      │   (:8091)    │ │   (:8080)    │ │   (:8089)    │
                      └───────┬──────┘ └──────┬───────┘ └──────┬───────┘
                              │               │                │
                              └───────────────┼────────────────┘
                                              ▼
                      ┌────────────────────────────────────────┐
                      │   PostgreSQL 16 + PostGIS (:5432)      │
                      │   - users, driver_capabilities         │
                      │   - orders (realtime lifecycle)        │
                      │   - merchants, menu_items              │
                      └────────────────────────────────────────┘
```

---

## 2. Bảng Cổng & Biến Môi Trường (Port Mapping & Config)

| Thành phần | Cổng (Port) | Giao thức | Ghi chú quan trọng |
|---|---|---|---|
| **api-gateway** | `8000` | HTTP | **BẮT BUỘC** chạy trên `8000` (`HTTP_PORT=8000`). Tránh xung đột với `ride-service` (:8080). |
| **ride-service** | `8080` | HTTP | Quản lý đặt xe và tính cước |
| **driver-service** | `8081` | HTTP / gRPC (:50051) | Quản lý thông tin tài xế và nhận cuốc |
| **user-service** | `8091` | HTTP | Quản lý đăng ký, đăng nhập, JWT tokens |
| **order-service** | `8088` | HTTP / gRPC (:50058) | Quản lý đơn hàng food/grocery |
| **merchant-service** | `8089` | HTTP / gRPC (:50059) | Quản lý quán ăn và thực đơn |
| **PostgreSQL** | `5432` | TCP | `xebuonho-postgres` (User: `postgres`, Pass: `postgres`, DB: `xebuonho`) |
| **Redis** | `6379` | TCP | `xebuonho-redis` |
| **Kafka** | `9092` | TCP | `xebuonho-kafka` |
| **EMQX MQTT** | `1883`, `18083` | TCP / HTTP | Dashboard quản trị tại `http://localhost:18083` |

### Biến môi trường cốt lõi:
```bash
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/xebuonho?sslmode=disable"
export JWT_SECRET="dev-secret-change-me-in-production"
export HTTP_PORT=8000
```
> [!IMPORTANT]
> Cả `user-service` và `api-gateway` phải sử dụng chung `JWT_SECRET` để token tạo ra khi đăng nhập được gateway giải mã và xác thực hợp lệ.

---

## 3. Kiến Trúc Dual-Role (Khách hàng & Tài xế)

Toàn bộ logic Tài xế được tách độc lập trong Flutter tại `apps/rider`:
- **Domain Models**: [`lib/models/driver_models.dart`](file:///Users/hwg/Documents/xebuonho/apps/rider/lib/models/driver_models.dart) (`DriverStatus`, `DriverTripStatus`, `DriverRideRequest`, `DriverTrip`, `DriverDailyStats`).
- **State Management**: [`lib/providers/driver_provider.dart`](file:///Users/hwg/Documents/xebuonho/apps/rider/lib/providers/driver_provider.dart) tự động polling cuốc từ PostgreSQL khi Online, nhận cuốc, chuyển trạng thái `arrived` -> `picked_up` -> `completed`, tính doanh thu.
- **Giao diện Tài xế**: [`lib/screens/driver/`](file:///Users/hwg/Documents/xebuonho/apps/rider/lib/screens/driver/) gồm:
  - `driver_dashboard_screen.dart`: Bảng điều khiển radar, nhận cuốc, bản đồ điều hướng.
  - `driver_history_screen.dart`: Lịch sử và thu nhập.
- **Chuyển đổi vai trò**:
  - Tại màn hình đăng nhập: 2 nút 1-chạm `[🙋‍♂️ Khách (Demo)]` và `[🚕 Tài xế (Demo)]`.
  - Trong ứng dụng: Banner chuyển đổi tại `lib/widgets/app_drawer.dart`.

---

## 4. Dữ Liệu Thật & PostGIS (Real Database Layer)

### 4.1. Tài khoản Demo thật:
- **Khách hàng**: `0901234567` / `password123` (ID: `ca3065df-b201-4e92-a807-04b51354a8d3`)
- **Tài xế**: `0912345678` / `secret123` (ID: `93623b04-ecc7-4654-8846-e05f72ab8069`) - Xe: Toyota Vios 2023 `59-E1 888.66`.

### 4.2. Dữ liệu Quán ăn & Món ăn:
File script: [`migrations/seed_real_data.sql`](file:///Users/hwg/Documents/xebuonho/migrations/seed_real_data.sql)
Bao gồm:
- 5 Quán ăn thực tế tại TP.HCM kèm tọa độ GPS chính xác.
- 13 Món ăn có đơn giá và hình ảnh thực tế.
- Bảng `orders` lưu trữ toàn bộ trạng thái và tọa độ đón/trả bằng `GEOGRAPHY(POINT, 4326)`.

---

## 5. Quy Trình Chạy & Kiểm Thử (Testing & Execution)

### Bước 1: Khởi động Hạ tầng Docker
```bash
docker compose up -d
```

### Bước 2: Nạp dữ liệu Seed
```bash
docker exec -i xebuonho-postgres psql -U postgres -d xebuonho < migrations/seed_real_data.sql
```

### Bước 3: Khởi động Backend Services
```bash
./scripts/run-services.sh
# Hoặc khởi động api-gateway thủ công:
HTTP_PORT=8000 DATABASE_URL="postgres://postgres:postgres@localhost:5432/xebuonho?sslmode=disable" JWT_SECRET="dev-secret-change-me-in-production" ./services/api-gateway/bin/api-gateway
```

### Bước 4: Chạy ứng dụng Flutter
```bash
cd apps/rider
flutter run -d chrome
```

### Bước 5: Kịch bản kiểm thử Dual Role End-to-End:
1. Mở trình duyệt Chrome tab thường: Bấm `[🙋‍♂️ Khách (Demo)]` -> Vào mục Đặt xe hoặc Quán ăn -> Tạo chuyến xe / đặt món. Hệ thống sẽ ghi nhận 1 bản ghi vào bảng `orders` của PostgreSQL với status `created`.
2. Mở trình duyệt Chrome tab ẩn danh (Incognito): Bấm `[🚕 Tài xế (Demo)]` -> Bật công tắc **"Sẵn sàng nhận cuốc" (Online)**.
3. Trong vòng 4 giây, hệ thống sẽ tự động quét cuốc xe mới nhất từ PostgreSQL và hiển thị Modal Nhận Cuốc trên màn hình tài xế!
4. Tài xế bấm **"Nhận cuốc ngay"**: Chuyến đi chuyển sang chế độ đón khách, status trong PostgreSQL được cập nhật sang `accepted`.
5. Tài xế bấm **"Đã tới điểm đón"** -> **"Bắt đầu chuyến đi"** -> **"Hoàn thành chuyến đi"**: Bản ghi trong PostgreSQL cập nhật sang `completed`, doanh thu tài xế được cộng dồn ngay tức thì.

---

## 6. Hướng Dẫn Mở Rộng Tương Lai (Extensibility Roadmap)

### 6.1. Tách thành Standalone Driver App (`apps/driver`):
Tất cả các thành phần trong `lib/screens/driver/`, `lib/models/driver_models.dart`, và `lib/providers/driver_provider.dart` hoàn toàn độc lập với phần Rider. Khi tách:
1. Sao chép thư mục: `cp -r apps/rider apps/driver`.
2. Đổi `initialRoute` trong `main.dart` thành `/driver`.
3. Xóa các màn hình của khách hàng, tích hợp thêm Background Geolocation Service (xem skill `mobile-native-driver`).

### 6.2. Thêm Dịch Vụ Mới (Ví dụ: Thuê Xe Theo Giờ / Đi Xe Liên Tỉnh):
1. Cập nhật enum `ServiceType` trong `lib/models/ride.dart`.
2. Thêm giá trị tương ứng vào cột `service_type` của bảng `orders` và bảng `driver_capabilities`.
3. Viết thêm hàm tính cước (Fare Strategy) trong `ride-service` hoặc `api-gateway/internal/service`.

### 6.3. Tích Hợp Cổng Thanh Toán Trực Tuyến:
1. Tạo module `payment-service` hoặc mở rộng `api-gateway` gọi VNPay / MoMo API Sandbox.
2. Thêm IPN webhook cập nhật trạng thái đơn hàng (`orders.payment_status = 'paid'`).
