---
name: Golang Backend Development
description: Hướng dẫn phát triển backend microservices bằng Go - coding standards, patterns, và project structure.
---

# Golang Backend Development

## Khi nào dùng skill này?
- Tạo mới hoặc sửa đổi bất kỳ microservice nào
- Cần hiểu project structure và coding conventions
- Debug hoặc optimize Go code

## Tại sao Go?
- **Goroutines**: Xử lý hàng vạn concurrent requests với ít RAM
- **Static typing**: Catch bugs tại compile time
- **Fast compilation**: Build trong vài giây
- **Standard library**: HTTP server, JSON, crypto built-in

## Project Structure (mỗi service)
```
services/{service-name}/
├── cmd/main.go           # Entry point
├── internal/
│   ├── handler/          # HTTP/gRPC handlers (input validation)
│   ├── service/          # Business logic (core domain)
│   ├── repository/       # Data access (DB queries)
│   ├── model/            # Domain models
│   └── config/           # Configuration loading
├── migrations/           # SQL migrations
├── go.mod
├── Dockerfile
└── Makefile
```

## Key Dependencies
```
github.com/gin-gonic/gin          # HTTP framework
google.golang.org/grpc            # gRPC
github.com/redis/go-redis/v9      # Redis client
github.com/jackc/pgx/v5           # PostgreSQL driver
github.com/segmentio/kafka-go     # Kafka client
github.com/eclipse/paho.mqtt.golang # MQTT client
go.uber.org/zap                   # Structured logging
```

## Must-Follow Rules
1. Always pass `context.Context` as first param
2. Always return `error` as last return value
3. Use table-driven tests
4. Use `golangci-lint` for linting
5. No global mutable state

---

## Security & Reliability Standards (Bảo Mật & Độ Tin Cậy)

### 1. Bọc Panic Trong Mọi Goroutine Bất Đồng Bộ
Một panic không được bắt trong goroutine con sẽ làm sập toàn bộ tiến trình (crash process):
```go
go func() {
    defer func() {
        if r := recover(); r != nil {
            logger.Error("Recovered from goroutine panic", zap.Any("panic", r), zap.Stack("stack"))
        }
    }()
    // business logic
}()
```

### 2. Chống Rò Rỉ Thông Tin Nội Bộ (Information Disclosure)
- **Không bao giờ trả về lỗi thô (Raw SQL / Stacktrace) cho client**:
  ```go
  // SAI: writeJSON(w, 500, map[string]string{"error": err.Error()}) // Lộ cấu trúc bảng SQL
  
  // ĐÚNG:
  logger.Error("Database query failed", zap.Error(err))
  writeJSON(w, http.StatusInternalServerError, map[string]string{
      "error": "Có lỗi hệ thống xảy ra. Vui lòng thử lại sau.",
      "code":  "INTERNAL_ERROR",
  })
  ```

### 3. Middleware Bảo Mật Chuẩn (Security Headers & CORS)
- Thiết lập header: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Strict-Transport-Security: max-age=31536000`.
- CORS: Không dùng `Allow-Origin: *` cho các endpoint nhận cookie/token nhạy cảm.

### 4. Input Validation & Giới Hạn Payload
- Giới hạn kích thước body: `http.MaxBytesReader(w, r.Body, 1<<20)` (tối đa 1MB, chống tấn công cạn kiệt RAM).
- Ràng buộc dữ liệu vào bằng struct tags hoặc validator.

### 5. Graceful Shutdown
Luôn lắng nghe `os.Interrupt` và `syscall.SIGTERM`, đợi các request đang chạy hoàn tất với timeout 10 giây trước khi ngắt tiến trình:
```go
quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit
ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
defer cancel()
server.Shutdown(ctx)
```

---

## Design Patterns Chuẩn Toàn Dự Án (Architectural Patterns)

Hệ thống backend `xebuonho` áp dụng nghiêm ngặt các mẫu thiết kế hướng đối tượng & hướng miền (DDD) sau:

### 1. Strategy Pattern & Factory Pattern (Động cơ Định giá Đa Dịch vụ)
- **Vấn đề**: Mỗi loại dịch vụ (`ride`, `food_delivery`, `grocery`, `designated_driver`) có công thức tính cước, phụ phí đêm, chế độ tài xế hộ (Solo/Duo) và phí chọn đồ hoàn toàn khác nhau. Không được viết `if-else` lộn xộn trong handler.
- **Giải pháp**:
  - Giao diện `PricingStrategy` đóng gói thuật toán tính giá:
    ```go
    type PricingStrategy interface {
        Calculate(ctx PricingContext) PricingResult
    }
    ```
  - Triển khai riêng biệt: `StandardRideStrategy`, `FoodDeliveryStrategy`, `GroceryShoppingStrategy`, `DesignatedDriverStrategy`.
  - `PricingFactory` (Factory Pattern): Cung cấp đúng Strategy dựa trên `serviceType` mà không làm lộ chi tiết khởi tạo.

### 2. State Pattern & Finite State Machine - FSM (Vòng Đời Đơn Hàng)
- **Vấn đề**: Ngăn chặn nhảy cóc trạng thái phi lý (ví dụ: cuốc vừa nhận `accepted` đã nhảy thẳng sang `completed`, hoặc hủy cuốc khi khách đã lên xe).
- **Giải pháp**:
  - `OrderStateMachine` quy định đồ thị chuyển đổi trạng thái hợp lệ:
    - `created` ➔ `accepted` | `cancelled_by_customer`
    - `accepted` ➔ `arriving` | `arrived` | `cancelled_by_driver` | `cancelled_by_customer`
    - `arriving` ➔ `arrived` | `cancelled_by_driver`
    - `arrived` ➔ `in_progress` | `cancelled_by_driver`
    - `in_progress` ➔ `completed` (kết thúc)
  - Mọi thao tác cập nhật trạng thái đều phải qua `orderstate.ValidateTransition(current, target)`. Nếu vi phạm sẽ trả về `400 Bad Request`.

### 3. Repository Pattern & Dependency Inversion Principle (DIP)
- **Vấn đề**: Handlers không được phụ thuộc trực tiếp vào struct cụ thể của cơ sở dữ liệu (`*PostgresRepo`), gây khó khăn cho việc viết unit test/mocking.
- **Giải pháp**:
  - Định nghĩa Interfaces: `OrderRepository`, `MerchantRepository`.
  - Handlers (`RideHandler`, `DriverHandler`) chỉ nhận Interface qua Constructor Injection:
    ```go
    type RideHandler struct {
        client *grpcclient.RideClient
        repo   repository.OrderRepository // Interface
    }
    ```

### 4. Observer Pattern / Event Dispatcher (Phân Phối Sự Kiện Miền)
- **Vấn đề**: Khi cuốc xe được tạo (`order.created`) hoặc tài xế nhận cuốc (`order.accepted`), hệ thống cần gửi thông báo WebSocket, ghi log kiểm toán, và đẩy push notification mà không làm tăng coupling của nghiệp vụ chính.
- **Giải pháp**:
  - `event.GetDispatcher()` cung cấp cơ chế Subscribe & Dispatch bất đồng bộ:
    ```go
    // Phát tán sự kiện
    event.GetDispatcher().Dispatch(ctx, event.Event{
        Type:    event.EventOrderCreated,
        Payload: rideRes,
    })
    
    // Đăng ký nhận (trong router hoặc notification hub)
    event.GetDispatcher().Subscribe(event.EventOrderCreated, func(ctx context.Context, e event.Event) error {
        notifHub.SendToRole("driver", notification)
        return nil
    })
    ```

### 5. Decorator / Middleware Pattern (Xử Lý Yêu Cầu Đầu Vào)
- Chained HTTP Middlewares để xử lý các khía cạnh chung (Cross-cutting Concerns):
  - `authMiddleware`: Xác thực JWT và trích xuất `user_id`, `role`.
  - `rateLimiter`: Chống brute-force và DoS.
  - `securityHeaders`: Bảo vệ HTTP response headers.

---

## References
- Coding standards: [rules/CODING-STANDARDS.md](../../rules/CODING-STANDARDS.md)
- Error handling: [rules/ERROR-HANDLING.md](../../rules/ERROR-HANDLING.md)
- Security & Anti-Fraud: [skills/security-anti-fraud/SKILL.md](../security-anti-fraud/SKILL.md)


