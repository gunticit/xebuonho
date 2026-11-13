# Kế hoạch Triển khai Hệ thống Quản trị Đồng nhất (Unified Admin System Plan)
**Dự án:** XeBuonHo Platform  
**Ngày lập:** 12/11/2026  
**Trạng thái:** Đang triển khai  

---

## 1. Mục tiêu
Xây dựng trải nghiệm quản trị đồng nhất giữa **Web Admin (Desktop Browser)** và **Ứng dụng Admin (Mobile/Web Flutter)**, kết nối chung nguồn dữ liệu Backend, cùng tiêu chuẩn thiết kế Dark Theme cao cấp và dùng chung hạ tầng bản đồ (Esri Dark Canvas + Amazon Location Service).

---

## 2. Ma trận Tính năng Đồng nhất

| Phân hệ | Web Admin (`:8000/`) | App Admin (`apps/rider`) | Backend API |
| :--- | :--- | :--- | :--- |
| **1. 📊 Thống kê & Doanh thu** | KPI cards, Biểu đồ 7 ngày, tỷ trọng 4 dịch vụ, giờ cao điểm | Thẻ KPI, Biểu đồ doanh thu 4 dịch vụ, cuốc xe hôm nay | `/api/v1/admin/stats`, `/api/v1/admin/revenue` |
| **2. 🛡️ Duyệt hồ sơ tài xế (KYC)** | Hàng đợi 4 tab (`pending_approval`, `approved`, `rejected`, `suspended`), Modal xem ảnh CCCD/GPLX/Cà vẹt/Bảo hiểm, Duyệt/Từ chối | `AdminDriverListScreen`, `AdminDriverDetailScreen`, Modal duyệt/từ chối tiếng Việt | `/api/v1/auth/admin/drivers`, `/api/v1/auth/admin/drivers/:id`, `/api/v1/auth/admin/drivers/:id/approval` |
| **3. 📋 Quản lý Cuốc xe** | Bảng danh sách đơn hàng realtime, xem chi tiết lộ trình, hủy khẩn cấp | Danh sách hoạt động cuốc xe, lọc trạng thái, tra cứu mã đơn | `/api/v1/admin/orders/recent` |
| **4. 🗺️ Bản đồ Đội xe Trực tuyến** | Leaflet.js nhúng bản đồ Esri Dark Canvas + Marker tài xế realtime | `flutter_map` với tile Esri Dark Canvas, radar vị trí tài xế | `/api/v1/driver/location/nearby`, `/api/v1/maps/route` |
| **5. 💰 Ví tiền & Bảng giá** | Quản lý ví tài xế, duyệt rút tiền, xem cấu hình phụ phí | Thẻ quản lý ví tiền, xem bảng giá cước 4 dịch vụ | `/api/v1/wallets`, `/api/v1/rides/estimate` |

---

## 3. Kiến trúc Bản đồ & API Key Dùng chung
* **Lớp Tile nền (Basemap):** Esri World Dark Gray Canvas (`https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}`) kết hợp Overlay Labels (`Canvas/World_Dark_Gray_Reference`). Tone màu tối sang trọng, không watermark, không giới hạn request.
* **Lớp Fallback:** OpenStreetMap Raster Tiles.
* **Lớp Định tuyến & Tìm kiếm:** Amazon Location Service API Key (`ApiConfig.awsLocationApiKey`) kết hợp API Gateway nội bộ (`/api/v1/maps/route` & `/api/v1/maps/reverse-geocode`).

---

## 4. Lộ trình Triển khai Chi tiết

### Bước 1: Hoàn thiện Backend & API Gateway
- Đảm bảo API Gateway proxy đầy đủ các route Admin:
  - `/api/v1/admin/stats`
  - `/api/v1/admin/revenue`
  - `/api/v1/admin/orders/recent`
  - `/api/v1/admin/drivers` ➔ Proxy tới `user-service`
  - `/api/v1/admin/drivers/:id/approval` ➔ Proxy tới `user-service`

### Bước 2: Nâng cấp Web Admin Dashboard (`services/api-gateway/internal/router/static/index.html`)
- Cấu trúc lại giao diện với Sidebar/TabBar 5 phân hệ:
  1. `[📊 Tổng quan]` — Dashboard KPI & Biểu đồ doanh thu
  2. `[🛡️ Duyệt tài xế (KYC)]` — Quản lý hồ sơ đối tác, xem ảnh MinIO, duyệt/từ chối
  3. `[📋 Quản lý Cuốc xe]` — Giám sát các chuyến đi đang diễn ra
  4. `[🗺️ Bản đồ đội xe]` — Bản đồ Leaflet với tile Esri Dark Canvas xem tài xế online
  5. `[💰 Tài chính]` — Doanh thu & ví đối tác
- Toàn bộ ngôn ngữ thông báo và cảnh báo chuẩn hóa 100% Tiếng Việt.

### Bước 3: Nâng cấp Ứng dụng Admin Flutter (`apps/rider`)
- Bổ sung `AdminProvider` ([admin_provider.dart](file:///Users/hwg/Documents/xebuonho/apps/rider/lib/providers/admin_provider.dart)): Load thống kê, doanh thu, đơn hàng gần đây từ API Gateway.
- Tạo màn hình điều hướng trung tâm `AdminDashboardScreen` tích hợp Bottom Navigation Bar:
  - Tab 1: **📊 Thống kê (Dashboard)**
  - Tab 2: **🛡️ Duyệt KYC (Hồ sơ đối tác)**
  - Tab 3: **📋 Cuốc xe (Live Orders)**
  - Tab 4: **🗺️ Bản đồ xe (Fleet Map)**
- Đồng bộ route `/admin` trong `main.dart` chuyển hướng đến màn hình trung tâm.

### Bước 4: Kiểm thử & Khởi động lại dịch vụ
- Biên dịch lại `bin/api-gateway` và `bin/user-service`.
- Khởi động lại các service và kiểm tra trên cả Chrome Web (`http://localhost:8000`) lẫn ứng dụng Flutter (`flutter run`).

