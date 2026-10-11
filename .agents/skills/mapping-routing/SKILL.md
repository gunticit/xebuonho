---
name: Mapping & Routing Integration
description: Hướng dẫn tích hợp Maps API (Goong/Mapbox/OSRM), tính cước Upfront Pricing an toàn, thuật toán định tuyến và bộ nhớ đệm chống tốn chi phí.
---

# Mapping & Routing Integration Guide

## 1. Khi nào dùng skill này?
- Tích hợp Geocoding (Địa chỉ ↔ Tọa độ GPS), Autocomplete tìm kiếm địa điểm tại Việt Nam.
- Lấy lộ trình đường đi (Routing/Directions API) và vẽ đường đi (Polyline) trên bản đồ Flutter/Web.
- Tính cước chuyến đi cố định (**Upfront Fare Pricing**) có khóa thời hạn và chữ ký chống sửa giá.
- Tối ưu hóa chi phí gọi Maps API bên ngoài (Goong, Mapbox, Google Maps) thông qua bộ đệm đa tầng Redis/PostGIS.
- Triển khai thuật toán tính cước dự phòng nội bộ (PostGIS Curvature Factor Fallback) khi mất kết nối mạng ngoài.

---

## 2. So Sánh & Lựa Chọn Nhà Cung Cấp Bản Đồ Tại Việt Nam

| Nhà cung cấp | Ưu điểm | Nhược điểm | Trường hợp sử dụng tối ưu |
|---|---|---|---|
| **Goong Maps** *(Khuyên dùng số 1)* | Dữ liệu ngõ ngách, số nhà Việt Nam xuất sắc; Giá thành rẻ (VNĐ); Độ trễ thấp (<80ms) | Ít tùy biến giao diện đồ họa vector quốc tế | **Geocoding, Autocomplete, Directions chính thức** |
| **Mapbox GL** | Vector tile đẹp mắt; Tùy biến theme bản đồ tối/sáng; SDK mobile rất mượt mà | Geocoding số nhà phụ tại Việt Nam chưa hoàn hảo | **Hiển thị bản đồ (Map Tiles) trên Flutter/Web** |
| **Google Maps** | Độ phủ dữ liệu toàn cầu tốt nhất | Chi phí cực đắt ($5-$10 / 1,000 requests); Tính theo USD | Chỉ dùng làm Fallback cấp 3 |
| **OSRM Tự Host** | Hoàn toàn miễn phí; Không giới hạn số lượt gọi | Cần máy chủ RAM > 16GB để nạp dữ liệu OSM Việt Nam | Tính toán ma trận khoảng cách nội bộ (Distance Matrix) |

---

## 3. Khóa Giá Cước Cố Định (Upfront Fare Locking & Anti-Tampering)

### 3.1. Rủi ro gian lận giá
Nếu client Flutter tự tính giá hoặc gửi `fare_estimate` lên server trong request `POST /rides`, kẻ xấu có thể can thiệp HTTP Proxy (Charles/BurpSuite) sửa giá chuyến đi từ 150,000đ xuống 1,000đ.

### 3.2. Giải pháp: Fare Quote Token (Khóa giá 10 phút)
```
1. Khách nhập Điểm đón + Điểm đến
2. Client gọi: POST /api/v1/rides/estimate
   Server tính toán:
   - Khoảng cách km (Directions API)
   - Thời gian ước tính (phút)
   - Hệ số Surge Pricing theo thời tiết / giờ cao điểm
   - Sinh quote_id = UUID
   - Lưu vào Redis: key = "fare_quote:" + quote_id, TTL = 10 phút
   Server trả về: { quote_id, total_fare, distance_km, duration_min }
3. Client xác nhận đặt xe: POST /api/v1/rides
   Gửi kèm: { quote_id, pickup_lat, pickup_lng, ... }
4. Server đọc quote_id từ Redis:
   - Nếu tồn tại: Lấy đúng total_fare đã lưu làm giá chốt cho đơn hàng.
   - Nếu hết hạn hoặc sai: Từ chối đơn hàng, yêu cầu tính lại giá.
```

---

## 4. Thuật Toán Tính Cước Dự Phòng Nội Bộ (Offline PostGIS Fallback)

Khi mạng ngoài mất kết nối hoặc hết quota Goong API, hệ thống kích hoạt cơ chế Fallback sử dụng PostGIS kết hợp hệ số uốn khúc đô thị (**Urban Tortuosity Factor**):

```go
// Khoảng cách đường chim bay (Haversine/PostGIS ST_Distance)
straightLineDistanceKm := HaversineDistance(pickupLat, pickupLng, dropoffLat, dropoffLng)

// Tại đô thị TP.HCM / Hà Nội, đường thực tế dài hơn đường chim bay từ 1.30 đến 1.40 lần
const UrbanTortuosityFactor = 1.35 
estimatedRoadKm := straightLineDistanceKm * UrbanTortuosityFactor

// Ước tính vận tốc trung bình đô thị 25 km/h
durationMinutes := int((estimatedRoadKm / 25.0) * 60) + 5
```

---

## 5. Chiến Lược Cache Đa Tầng Tối Ưu Chi Phí API (Cost Optimization)

Mỗi ngày có hàng trăm ngàn lượt tra cứu cùng một lộ trình (ví dụ: *Sân bay Tân Sơn Nhất* ↔ *Landmark 81*). Không được gọi API bên ngoài cho mỗi lượt bấm:

```
Request Tra Lộ Trình (pickup, dropoff)
                │
                ▼
Tạo GeoHash Key cấp độ 6 (~1.2km):
CacheKey = fmt.Sprintf("route:%s:%s", geohash(pickup, 6), geohash(dropoff, 6))
                │
                ▼
Kiểm tra Redis Cache (TTL = 15 phút)
    ├── Có trong Cache ──▶ Trả về ngay (Độ trễ < 2ms, Chi phí = 0đ)
    └── Không có trong Cache
            │
            ▼
        Gọi Goong / Mapbox Directions API
            │
            ▼
        Lưu kết quả vào Redis + Trả về client
```

---

## 6. Giải Mã & Vẽ Polyline Trên Flutter (`apps/rider`)

Các Directions API trả về chuỗi mã hóa `overview_polyline` (chuỗi ký tự nén điểm tọa độ).
Trong Flutter (`apps/rider/lib/screens/tracking_screen.dart`):

```dart
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

List<LatLng> decodePolyline(String encodedString) {
  PolylinePoints polylinePoints = PolylinePoints();
  List<PointLatLng> result = polylinePoints.decodePolyline(encodedString);
  return result.map((p) => LatLng(p.latitude, p.longitude)).toList();
}
```

---

## 7. References Trong Dự Án
- **Chi tiết kiến trúc**: [`docs/architecture/MAPPING-ROUTING.md`](../../docs/architecture/MAPPING-ROUTING.md)
- **Tầng dữ liệu không gian**: [`skills/postgresql-postgis/SKILL.md`](../postgresql-postgis/SKILL.md)
- **Bộ nhớ đệm Redis**: [`skills/redis-geospatial/SKILL.md`](../redis-geospatial/SKILL.md)
- **Xử lý trên Gateway**: [`services/api-gateway/internal/handler/ride_handler.go`](../../services/api-gateway/internal/handler/ride_handler.go)
