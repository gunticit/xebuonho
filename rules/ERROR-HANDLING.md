# 🛡️ Error Handling Rules

## Nguyên tắc chung

1. **Never ignore errors** - Mọi error phải được handle hoặc propagate
2. **Wrap errors with context** - Thêm context khi propagate error
3. **Use typed errors** - Define error types cho mỗi domain
4. **Fail fast, recover gracefully** - Validate sớm, recover ở tầng cao nhất

## Error Types

```go
package apperror

// Base error types
type AppError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Detail  string `json:"detail,omitempty"`
    Err     error  `json:"-"`
}

func (e *AppError) Error() string { return e.Message }
func (e *AppError) Unwrap() error { return e.Err }

// Domain errors
var (
    // Ride errors
    ErrRideNotFound       = &AppError{Code: "RIDE_NOT_FOUND", Message: "Không tìm thấy cuốc xe"}
    ErrRideAlreadyExists  = &AppError{Code: "RIDE_DUPLICATE", Message: "Cuốc xe đã tồn tại"}
    ErrInvalidTransition  = &AppError{Code: "INVALID_TRANSITION", Message: "Chuyển trạng thái không hợp lệ"}
    
    // Driver errors
    ErrDriverNotFound     = &AppError{Code: "DRIVER_NOT_FOUND", Message: "Không tìm thấy tài xế"}
    ErrDriverBusy         = &AppError{Code: "DRIVER_BUSY", Message: "Tài xế đang bận"}
    ErrNoDriverAvailable  = &AppError{Code: "NO_DRIVER", Message: "Không có tài xế khả dụng"}
    
    // Payment errors
    ErrInsufficientBalance = &AppError{Code: "INSUFFICIENT_BALANCE", Message: "Số dư không đủ"}
    ErrPaymentFailed       = &AppError{Code: "PAYMENT_FAILED", Message: "Thanh toán thất bại"}
)
```

## Error Wrapping Pattern

```go
// ✅ Good: wrap error with context
func (s *RideService) GetRide(ctx context.Context, id string) (*Ride, error) {
    ride, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("get ride %s: %w", id, err) // wrap
    }
    if ride == nil {
        return nil, ErrRideNotFound
    }
    return ride, nil
}

// ❌ Bad: naked error
func (s *RideService) GetRide(ctx context.Context, id string) (*Ride, error) {
    return s.repo.FindByID(ctx, id) // no context if error
}
```

## gRPC Error Mapping

```go
func mapToGRPCError(err error) error {
    switch {
    case errors.Is(err, ErrRideNotFound):
        return status.Error(codes.NotFound, err.Error())
    case errors.Is(err, ErrRideAlreadyExists):
        return status.Error(codes.AlreadyExists, err.Error())
    case errors.Is(err, ErrInvalidTransition):
        return status.Error(codes.FailedPrecondition, err.Error())
    case errors.Is(err, ErrDriverBusy):
        return status.Error(codes.Unavailable, err.Error())
    default:
        return status.Error(codes.Internal, "internal server error")
    }
}
```

## Retry Policy

```go
// Exponential backoff with jitter
func withRetry(ctx context.Context, maxRetries int, fn func() error) error {
    var lastErr error
    for i := 0; i <= maxRetries; i++ {
        if err := fn(); err != nil {
            lastErr = err
            if !isRetryable(err) {
                return err // Non-retryable, fail fast
            }
            backoff := time.Duration(math.Pow(2, float64(i))) * 100 * time.Millisecond
            jitter := time.Duration(rand.Intn(100)) * time.Millisecond
            select {
            case <-time.After(backoff + jitter):
            case <-ctx.Done():
                return ctx.Err()
            }
            continue
        }
        return nil // Success
    }
    return fmt.Errorf("max retries exceeded: %w", lastErr)
}
```

## Panic Recovery

```go
// Middleware: recover from panics in HTTP/gRPC handlers
func RecoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if err := recover(); err != nil {
                log.Errorf("PANIC recovered: %v\n%s", err, debug.Stack())
                w.WriteHeader(http.StatusInternalServerError)
                json.NewEncoder(w).Encode(map[string]string{
                    "error": "internal server error",
                })
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```
