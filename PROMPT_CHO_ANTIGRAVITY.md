# Prompt giao việc cho Antigravity IDE Agent — XeBuonHo P0

Copy toàn bộ khối dưới đây và dán vào **Antigravity IDE > Agent Chat** (sidebar):

---

Bạn là agent phụ trách hoàn thiện dự án XeBuonHo tại `/Users/hwg/Documents/xebuonho`.

## BẮT BUỘC đọc trước khi code:
- `REVIEW_DU_AN.md` (báo cáo 13 chương, có roadmap P0/P1/P2)
- `docs/AI_DEVELOPER_GUIDE.md`
- `rules/CODING-STANDARDS.md`
- `.agents/skills/golang-backend/SKILL.md`
- `.agents/skills/redis-geospatial/SKILL.md` (cho matching/location)
- `.agents/skills/mqtt-realtime/SKILL.md` (cho location)
- `pkg/statemachine/statemachine.go` và `pkg/kafka/` (dùng chung)

## Nhiệm vụ P0 — làm theo thứ tự, mỗi service là 1 commit riêng:

### 1) matching-service (ưu tiên số 1)
- Redis GEORADIUS: tìm tài xế trong 2km -> 5km fallback, key `driver:geo`
- Gọi location-service (hoặc đọc Redis `driver:{id}:meta`) lấy ETA/rating
- Scoring: `score = w1*distance + w2*rating + w3*wait_time`, trả driver tốt nhất
- gRPC `FindNearbyDrivers(lat,lng,radius,service_type)` + HTTP `/health`
- Handle no_driver -> emit StatusNoDriver, retry với bán kính mở rộng
- Table-driven tests

### 2) location-service
- MQTT ingest từ EMQX (1883) topic `driver/{id}/location` -> GEOADD Redis `driver:geo` + SET `driver:{id}:meta` (lat,lng,heading,speed,timestamp)
- HTTP API: POST /location/update, GET /location/nearby, GET /drivers/{id}/location
- Publish vị trí qua Gateway WS Hub cho rider đang tracking
- Tests

### 3) driver-service
- POST /driver/online|offline, GET /driver/me, driver_capabilities (ride/food/grocery/designated_driver)
- Accept/Reject ride, state transitions qua pkg/statemachine
- Lưu PostgreSQL (bảng users + driver_capabilities), cache Redis
- Tests

### 4) Fix OTP in-memory -> Redis
- Trong `services/user-service/internal/handler/auth_handler.go`: thay `map+RWMutex` bằng `SET otp:{phone} code EX 300` Redis
- Verify bằng Lua script (atomic get+del), resend rate-limit 60s
- Test OTP flow

## Quy chuẩn:
- `context.Context` param đầu tiên, `error` return cuối cùng, validate ở handler, defer cleanup
- Dùng `pkg/statemachine` cho mọi chuyển trạng thái, `pkg/kafka` CloudEvent cho async
- Mỗi service: `internal/{handler,service,repository,model,config}/` + `migrations/`
- Sau mỗi service: `go vet ./... && go test -race ./... && make build`

## Verify cuối P0:
- `make build && make test` pass, `docker ps` infra healthy, `curl :8000/health` OK, Flutter `flutter analyze` OK

Báo cáo tiến độ sau mỗi service hoàn thành.
