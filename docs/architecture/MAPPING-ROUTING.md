# 🗺️ Bản đồ & Tính cước (Mapping & Routing)

## Lựa chọn Maps Provider

| Provider | Ưu điểm | Nhược điểm | Chi phí |
|----------|---------|-----------|---------|
| **Google Maps** | Chính xác nhất, traffic realtime | Chi phí rất cao | ~$7/1000 req |
| **Mapbox** | Đẹp, tùy biến cao, SDK tốt | Dữ liệu VN ít hơn | ~$1-3/1000 req |
| **Goong** (VN) | Dữ liệu VN tốt, giá rẻ | Limited outside VN | ~$0.5/1000 req |

> **Đề xuất**: Dùng **Goong** cho thị trường Việt Nam (giá rẻ, data tốt), fallback sang **Mapbox** cho custom UI.

---

## 1. Core Map Features

### Geocoding (Địa chỉ → Tọa độ)

```go
// Chuyển đổi địa chỉ thành tọa độ
type GeocodingService interface {
    // Forward: "123 Nguyễn Huệ, Q1" → (10.7731, 106.7030)
    Geocode(ctx context.Context, address string) (*Location, error)
    
    // Reverse: (10.7731, 106.7030) → "123 Nguyễn Huệ, Phường Bến Nghé, Quận 1"
    ReverseGeocode(ctx context.Context, lat, lng float64) (*Address, error)
    
    // Autocomplete: "ngu" → ["Nguyễn Huệ", "Nguyễn Du", ...]
    Autocomplete(ctx context.Context, query string, location *Location) ([]Suggestion, error)
}
```

### Routing (Tính đường đi)

```go
type RoutingService interface {
    // Tính đường từ A → B
    GetRoute(ctx context.Context, req RouteRequest) (*Route, error)
    
    // Tính ETA (thời gian ước tính)
    GetETA(ctx context.Context, origin, destination Location) (time.Duration, error)
    
    // Tính khoảng cách thực tế (theo đường đi, không phải đường chim bay)
    GetDistance(ctx context.Context, origin, destination Location) (float64, error)
}

type RouteRequest struct {
    Origin      Location
    Destination Location
    Waypoints   []Location  // Điểm dừng giữa đường
    TrafficMode string      // "best_guess", "pessimistic", "optimistic"
    VehicleType string      // "car", "bike" (đường đi khác nhau)
}

type Route struct {
    DistanceKm     float64
    DurationMinutes int
    Polyline       string        // Encoded polyline để vẽ đường
    Steps          []RouteStep   // Turn-by-turn navigation
    TrafficDelayMin int          // Thời gian delay do kẹt xe
}
```

---

## 2. Tính cước (Fare Estimation)

### Công thức tính giá

```
Giá cuốc = Base Fare
          + (Distance × Price/km)
          + (Duration × Price/minute)
          + Surge Multiplier
          + Tolls (phí cầu đường)
          - Discount (mã giảm giá)
          + Platform Fee
```

### Go Implementation

```go
package fare

import "math"

type FareConfig struct {
    BaseFare       float64 // Giá mở cửa (VND)
    PricePerKm     float64 // Giá mỗi km
    PricePerMinute float64 // Giá mỗi phút
    MinFare        float64 // Giá tối thiểu
    PlatformFee    float64 // Phí nền tảng
    
    // Distance tiers (giá theo bậc km)
    Tier1Km    float64 // <= 2km: giá cao
    Tier1Price float64
    Tier2Km    float64 // 2-30km: giá thường
    Tier2Price float64
    Tier3Price float64 // > 30km: giá rẻ hơn
}

// VehicleType configs
var FareConfigs = map[string]FareConfig{
    "bike": {
        BaseFare: 12000, PricePerKm: 4200, PricePerMinute: 300,
        MinFare: 12000, PlatformFee: 2000,
        Tier1Km: 2, Tier1Price: 5000,
        Tier2Km: 30, Tier2Price: 4200,
        Tier3Price: 3800,
    },
    "car": {
        BaseFare: 25000, PricePerKm: 9500, PricePerMinute: 500,
        MinFare: 25000, PlatformFee: 3000,
        Tier1Km: 2, Tier1Price: 12000,
        Tier2Km: 30, Tier2Price: 9500,
        Tier3Price: 8500,
    },
    "premium": {
        BaseFare: 35000, PricePerKm: 14000, PricePerMinute: 800,
        MinFare: 35000, PlatformFee: 5000,
        Tier1Km: 2, Tier1Price: 16000,
        Tier2Km: 30, Tier2Price: 14000,
        Tier3Price: 12000,
    },
}

type FareEstimate struct {
    BaseFare        float64
    DistanceFare    float64
    TimeFare        float64
    SurgeMultiplier float64
    SurgeAmount     float64
    Tolls           float64
    Discount        float64
    PlatformFee     float64
    TotalFare       float64
    Currency        string
}

func CalculateFare(
    vehicleType string,
    distanceKm float64,
    durationMinutes int,
    surgeMultiplier float64,
    tolls float64,
    discountAmount float64,
) FareEstimate {
    config := FareConfigs[vehicleType]
    
    // Tính giá theo bậc km
    var distanceFare float64
    remaining := distanceKm
    
    if remaining > 0 {
        tier1 := math.Min(remaining, config.Tier1Km)
        distanceFare += tier1 * config.Tier1Price
        remaining -= tier1
    }
    if remaining > 0 {
        tier2 := math.Min(remaining, config.Tier2Km-config.Tier1Km)
        distanceFare += tier2 * config.Tier2Price
        remaining -= tier2
    }
    if remaining > 0 {
        distanceFare += remaining * config.Tier3Price
    }
    
    timeFare := float64(durationMinutes) * config.PricePerMinute
    subtotal := config.BaseFare + distanceFare + timeFare
    surgeAmount := subtotal * (surgeMultiplier - 1)
    
    total := subtotal + surgeAmount + tolls + config.PlatformFee - discountAmount
    total = math.Max(total, config.MinFare)
    
    // Làm tròn lên 1000 VND
    total = math.Ceil(total/1000) * 1000
    
    return FareEstimate{
        BaseFare:        config.BaseFare,
        DistanceFare:    distanceFare,
        TimeFare:        timeFare,
        SurgeMultiplier: surgeMultiplier,
        SurgeAmount:     surgeAmount,
        Tolls:           tolls,
        Discount:        discountAmount,
        PlatformFee:     config.PlatformFee,
        TotalFare:       total,
        Currency:        "VND",
    }
}
```

---

## 3. Surge Pricing (Giá tăng vọt)

```
┌──────────────────────────────────────────────────┐
│ Surge Pricing Algorithm                           │
├──────────────────────────────────────────────────┤
│                                                   │
│ Inputs:                                           │
│   - Số request đặt xe trong khu vực (demand)      │
│   - Số tài xế online trong khu vực (supply)       │
│   - Thời gian chờ trung bình (wait time)          │
│                                                   │
│ demand_supply_ratio = demand / supply              │
│                                                   │
│ Ratio < 1.0  → Multiplier = 1.0x (giá thường)    │
│ Ratio 1.0-2.0 → Multiplier = 1.2x               │
│ Ratio 2.0-3.0 → Multiplier = 1.5x               │
│ Ratio 3.0-5.0 → Multiplier = 2.0x               │
│ Ratio > 5.0   → Multiplier = 2.5x (cap tối đa)  │
│                                                   │
│ ⚠️ Luôn hiển thị rõ cho khách biết                │
│ ⚠️ Cap tối đa 2.5x, không tăng vô hạn            │
│ ⚠️ Tính theo vùng hexagon (H3), không phải city   │
└──────────────────────────────────────────────────┘
```

---

## 4. Maps SDK Integration

### Driver App: Turn-by-turn Navigation

```kotlin
// Goong Navigation SDK (Android)
val origin = Point.fromLngLat(106.6297, 10.8231)
val destination = Point.fromLngLat(106.7012, 10.7915)

val navigationOptions = NavigationOptions.Builder()
    .profile(DirectionsCriteria.PROFILE_DRIVING)
    .language("vi")
    .voiceInstructions(true)
    .bannerInstructions(true)
    .build()

GoongNavigation.startNavigation(
    origin = origin,
    destination = destination,
    options = navigationOptions
)
```

### Rider App: Live Driver Tracking on Map

```dart
// Flutter + Mapbox GL
MapboxMap(
  initialCameraPosition: CameraPosition(
    target: pickupLocation,
    zoom: 15,
  ),
  onMapCreated: (controller) {
    // Add driver marker with rotation
    controller.addSymbol(SymbolOptions(
      geometry: driverPosition,
      iconImage: 'car-icon',
      iconRotate: driverHeading,
      iconSize: 0.8,
    ));
    
    // Draw route polyline
    controller.addLine(LineOptions(
      geometry: routePolyline,
      lineColor: '#4285F4',
      lineWidth: 4,
    ));
  },
)
```

---

## 5. Caching Strategy cho Maps API

Giảm chi phí API bằng caching thông minh:

```
┌────────────────────────────────────────────────┐
│ Level 1: In-memory cache (Redis)               │
│ TTL: 5 minutes                                  │
│ Key: geocode:{hash(address)}                    │
│ Hit rate target: > 40%                          │
├────────────────────────────────────────────────┤
│ Level 2: Database cache (PostgreSQL)            │
│ TTL: 7 days                                     │
│ Lưu kết quả geocode/routing cho địa điểm phổ   │
│ biến (sân bay, bến xe, trung tâm thương mại)   │
├────────────────────────────────────────────────┤
│ Level 3: Pre-computed routes                    │
│ TTL: 1 hour                                     │
│ Tính sẵn route giữa các điểm hot               │
│ (Tân Sơn Nhất ↔ Q1, Q7 ↔ Q2, ...)             │
└────────────────────────────────────────────────┘
```
