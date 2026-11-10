# Hoàn thiện Trip-service + Lịch sử & Đánh giá thật (vertical slice)

## Context
Review dự án (REVIEW_DU_AN.md) xác định trip-service là service trống duy nhất còn lại (stub 35 dòng), màn Lịch sử Flutter vẫn generate data giả (`_generateTrips(Random(42))`), và rating/tip ở trip_complete_screen không gửi đi đâu. Nguồn dữ liệu chuyến đã có sẵn: bảng unified `orders` (4 service_type), driver hoàn thành chuyến qua `POST /api/v1/driver/trip/update` action `completed` → gateway cập nhật `orders.status='completed'`, `fare_final`, `completed_at`.

**Thiết kế (KISS, theo pattern sẵn có):** trip-service = read-model truy vấn trực tiếp bảng `orders` (như ride-service `ListByRider` đã làm) + sở hữu bảng `trip_ratings` riêng. Không Kafka consumer, không materialize trips (YAGNI). Không gRPC pb thực (repo không commit .pb.go, mọi gRPC client đều là mock) → dùng **HTTP reverse proxy** như payment-service, kèm auth middleware ở gateway.

## 1. Migration — `services/trip-service/migrations/000001_create_trip_ratings.up.sql` (+ .down.sql)
- Bảng `trip_ratings`: `id UUID PK`, `order_id UUID NOT NULL`, `customer_id UUID`, `driver_id UUID`, `rated_by UUID NOT NULL`, `rated_role VARCHAR(20) CHECK ('rider','driver')`, `rating SMALLINT CHECK 1–5`, `tip_amount NUMERIC(12,2) DEFAULT 0`, `comment TEXT`, `created_at TIMESTAMPTZ`; UNIQUE(`order_id`, `rated_by`); index `driver_id` (cho summary).

## 2. Trip-service (HTTP :8086, gRPC health :50057)
Skeleton theo `services/ride-service` (main.go wiring: ConnectPostgres, mux có timeout, graceful shutdown, health server) + config pattern của payment-service:
- `internal/config/config.go` — DatabaseURL, HTTPPort(8086), GRPCPort(50057), JWTSecret
- `internal/model/trip.go` — Trip, RatingSummary
- `internal/repository/trip_repo.go` (pgx v5):
  - `ListTrips(userID, role, serviceType, page, pageSize)` — SELECT từ `orders` WHERE terminal status (`completed, paid, delivered, cancelled, cancelled_by_customer, cancelled_by_driver, merchant_rejected`), role=rider → `customer_id=...`, role=driver → `driver_id=...`; JOIN `users` lấy tên/xe tài xế; LEFT JOIN `trip_ratings`; + COUNT phân trang
  - `GetTrip(id, userID)`; `UpsertRating(...)` ON CONFLICT; `GetRatingSummary(driverID)` (avg + count từ rating của rider)
- `internal/service/trip_service.go` — validate rating 1–5, chỉ participant mới được rate, đơn phải ở trạng thái terminal
- `internal/handler/http_handler.go` — REST: `GET /trips`, `GET /trips/{id}`, `POST /trips/{id}/rating`, `GET /drivers/{id}/rating-summary`, `GET /health`; xác thực: parse JWT (cùng secret với gateway/user-service, dùng cùng lib user-service đang dùng) lấy user id, fallback `user_id` param cho dev
- `proto/trip/trip_service.proto` — viết proto (ListTrips/GetTrip/SubmitRating/GetRatingSummary, go_package `github.com/xebuonho/proto/trip`) nhưng chỉ register health server, để commented pb registration như ride-service (theo convention repo)
- `go.mod`: thêm pgx v5, grpc, `replace github.com/xebuonho/pkg => ../../pkg`, `go mod tidy`

## 3. Gateway — `services/api-gateway/internal/router/router.go`
- `TRIP_SERVICE_URL` default `http://localhost:8086`; đăng ký TRƯỚC catch-all `/api/v1/`:
  `mux.Handle("/api/v1/trips/", auth(http.HandlerFunc(...proxyToService(tripServiceURL))))` — có auth (khác payments hiện tại), forward cả header Authorization để trip-service tự parse JWT

## 4. Flutter (`apps/rider/lib/`)
- `config/api_config.dart`: thêm `trips`, `tripDetail(id)`, `tripRating(id)`
- `services/api_service.dart`: `getTripHistory({role, serviceType, page})`, `submitTripRating(orderId, {rating, tip, comment})` — theo pattern dio hiện có
- `models/trip.dart`: `TripModel.fromJson` snake_case (theo RideModel)
- `providers/trip_provider.dart`: load/refresh/error/empty; đăng ký trong MultiProvider `main.dart`
- `screens/history_screen.dart`: bỏ `_generateTrips` — dùng TripProvider, RefreshIndicator, empty state, giữ nguyên card widgets, map service_type → tab
- `screens/trip_complete_screen.dart`: dùng `booking.currentRide` thay tài xế hardcode; gửi rating+tip qua ApiService trước `booking.reset()`; thêm ô comment
- `screens/tracking_screen.dart`: khi poll thấy status `completed` → điều hướng 1 lần sang `/complete` (xác minh logic poll khi làm)

## 5. Docs
- `docs/AI_DEVELOPER_GUIDE.md`: thêm trip endpoints vào bảng API; README đã có port 8086/50057 sẵn

## 6. Verification
1. `go build ./...` (trip-service, api-gateway qua go.work) + `go vet`
2. Chạy migration: `docker exec -i xebuonho-postgres psql ... < migrations/000001_*.up.sql` (nếu Docker đang chạy)
3. Chạy trip-service + gateway → curl e2e: login user seed `0901234567/password123` lấy JWT → `GET /api/v1/trips` → `POST /trips/{id}/rating` → verify avg rating thay đổi
4. `flutter analyze` trong apps/rider; chạy thử web + xem màn Lịch sử render data thật (browser automation nếu cần)

## Câu hỏi chưa giải quyết
- Cần xác minh tracking_screen polling có sẵn điểm hook chuyển `/complete` không (nếu phức tạp sẽ tách làm bước sau)
- Docker/Postgres local đang chạy hay không → ảnh hưởng bước verify e2e