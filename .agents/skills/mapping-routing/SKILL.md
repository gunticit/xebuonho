---
name: Mapping & Routing Integration
description: Hướng dẫn tích hợp Maps API (Goong/Mapbox/Google Maps) cho geocoding, routing, và fare calculation.
---

# Mapping & Routing Integration

## Khi nào dùng skill này?
- Tích hợp Maps API cho geocoding, routing
- Tính cước phí chuyến xe
- Implement surge pricing
- Optimize maps API cost

## Provider Selection (Việt Nam)
1. **Goong** (khuyên dùng): Giá rẻ, data VN tốt
2. **Mapbox**: UI đẹp, tùy biến cao
3. **Google Maps**: Chính xác nhất nhưng đắt

## Core APIs
| API | Mô tả | Provider |
|-----|--------|----------|
| Geocoding | Địa chỉ → Tọa độ | Goong/Google |
| Reverse Geocoding | Tọa độ → Địa chỉ | Goong/Google |
| Autocomplete | Gợi ý khi gõ | Goong/Google |
| Directions | Tính đường đi | Goong/Mapbox |
| Distance Matrix | Khoảng cách N→M | Goong/Google |
| Static Map | Hình ảnh bản đồ | Mapbox |

## Fare Calculation Formula
```
Total = Base + (Distance × Rate/km) + (Time × Rate/min)
      × Surge Multiplier + Tolls - Discount + Platform Fee
```

## Cost Optimization
- L1 Cache (Redis, 5min TTL)
- L2 Cache (PostgreSQL, 7 day TTL)
- Pre-compute popular routes
- Batch distance matrix calls

## References
- Chi tiết: [docs/architecture/MAPPING-ROUTING.md](../../docs/architecture/MAPPING-ROUTING.md)
