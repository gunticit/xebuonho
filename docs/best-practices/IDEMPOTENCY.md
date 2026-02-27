# 🔑 Idempotency (Tính Lũy đẳng)

> **Nguyên tắc #1**: Dù khách bấm "Đặt xe" 10 lần liên tục → Chỉ tạo **1 chuyến xe duy nhất**.

## Vấn đề

```
Khách hàng bực mình vì chưa thấy phản hồi
    ↓
Bấm "Đặt xe" 3-4 lần liên tục
    ↓
❌ KHÔNG CÓ IDEMPOTENCY:
    → 3-4 cuốc xe được tạo
    → 3-4 tài xế chạy đến đón 1 khách
    → Trừ tiền 3-4 lần
    → Khách hàng kiện, tài xế nổi giận

✅ CÓ IDEMPOTENCY:
    → Request thứ 2, 3, 4 trả về kết quả giống request 1
    → Chỉ 1 cuốc xe, 1 tài xế
    → OK!
```

## Cơ chế hoạt động

### 1. Idempotency Key

Mỗi request tạo cuốc xe phải gửi kèm một `idempotency_key` unique:

```
Idempotency Key = hash(rider_id + action + timestamp_rounded_to_30s)

Ví dụ:
  rider_id:    "user-abc123"
  action:      "create_ride"
  timestamp:   1705312200 (làm tròn 30s)
  → key:       "idem_abc123_ride_1705312200"
```

### 2. Server-side Implementation

```go
package ride

import (
    "context"
    "crypto/sha256"
    "fmt"
    "time"
)

type RideService struct {
    db    *sql.DB
    redis *redis.Client
    kafka *kafka.Producer
}

// CreateRide tạo cuốc xe với idempotency protection
func (s *RideService) CreateRide(ctx context.Context, req CreateRideRequest) (*Ride, error) {
    // ======================================
    // STEP 1: Generate idempotency key
    // ======================================
    idempotencyKey := req.IdempotencyKey
    if idempotencyKey == "" {
        // Auto-generate nếu client không gửi
        idempotencyKey = generateIdempotencyKey(req.RiderID, time.Now())
    }
    
    // ======================================
    // STEP 2: Check Redis cache (fast path)
    // ======================================
    cached, err := s.redis.Get(ctx, "idem:"+idempotencyKey).Result()
    if err == nil && cached != "" {
        // Request đã được xử lý trước đó → Trả về kết quả cũ
        var ride Ride
        json.Unmarshal([]byte(cached), &ride)
        return &ride, nil  // ← Idempotent response
    }
    
    // ======================================
    // STEP 3: Check Database (slow path, đề phòng Redis miss)
    // ======================================
    existingRide, err := s.db.QueryRow(ctx,
        "SELECT * FROM rides WHERE idempotency_key = $1", idempotencyKey)
    if err == nil && existingRide != nil {
        return existingRide, nil  // ← Đã có trong DB rồi
    }
    
    // ======================================
    // STEP 4: Acquire distributed lock
    // ======================================
    lockKey := "lock:ride:" + idempotencyKey
    acquired, err := s.redis.SetNX(ctx, lockKey, "1", 30*time.Second).Result()
    if !acquired {
        return nil, ErrRequestInProgress // Đang xử lý bởi request trước
    }
    defer s.redis.Del(ctx, lockKey) // Release lock
    
    // ======================================
    // STEP 5: Create ride (chỉ chạy 1 lần duy nhất)
    // ======================================
    ride := &Ride{
        ID:              uuid.New(),
        IdempotencyKey:  idempotencyKey,
        RiderID:         req.RiderID,
        PickupLocation:  req.Pickup,
        DropoffLocation: req.Dropoff,
        VehicleType:     req.VehicleType,
        Status:          StatusSearching,
        FareEstimate:    req.FareEstimate,
        RequestedAt:     time.Now(),
    }
    
    // Insert vào DB (idempotency_key là UNIQUE constraint)
    err = s.db.Insert(ctx, "rides", ride)
    if err != nil {
        if isUniqueViolation(err) {
            // Race condition: đã insert xong bởi request khác
            return s.getRideByIdempotencyKey(ctx, idempotencyKey)
        }
        return nil, err
    }
    
    // ======================================
    // STEP 6: Cache result (cho requests tiếp theo)
    // ======================================
    rideJSON, _ := json.Marshal(ride)
    s.redis.Set(ctx, "idem:"+idempotencyKey, rideJSON, 5*time.Minute)
    
    // ======================================
    // STEP 7: Publish event
    // ======================================
    s.kafka.Publish("ride.events", ride.ID.String(), RideCreatedEvent{
        RideID: ride.ID.String(),
        // ...
    })
    
    return ride, nil
}

func generateIdempotencyKey(riderID string, t time.Time) string {
    // Làm tròn timestamp về 30 giây
    rounded := t.Unix() / 30 * 30
    raw := fmt.Sprintf("%s:create_ride:%d", riderID, rounded)
    hash := sha256.Sum256([]byte(raw))
    return fmt.Sprintf("idem_%x", hash[:16])
}
```

### 3. Client-side Implementation

```dart
// Flutter Rider App
class RideBookingService {
  String? _lastIdempotencyKey;
  
  Future<Ride> bookRide(BookingRequest request) async {
    // Generate idempotency key
    final key = _generateKey(request);
    _lastIdempotencyKey = key;
    
    final response = await api.post('/rides', 
      body: request.toJson(),
      headers: {
        'Idempotency-Key': key,  // ← Gửi kèm header
      },
    );
    
    return Ride.fromJson(response.data);
  }
  
  String _generateKey(BookingRequest req) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 30000; // Round 30s
    return 'idem_${req.riderId}_ride_$timestamp';
  }
}
```

---

## Cheat Sheet

| Scenario | Giải pháp |
|----------|----------|
| Khách bấm "Đặt xe" 3 lần | Idempotency key (30s window) |
| Tài xế bấm "Hoàn thành" 2 lần | Check ride status trước khi transition |
| Payment webhook gọi 2 lần | Transaction ID unique constraint |
| Network retry gửi lại request | Server check idempotency key |
| 2 tài xế nhận cùng 1 cuốc | Distributed lock + DB check |
