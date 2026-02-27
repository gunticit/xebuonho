# API Documentation

## Base URL

```
Production: https://api.xebuonho.vn/v1
Staging:    https://staging-api.xebuonho.vn/v1
Local:      http://localhost:8080/v1
```

## Authentication

All endpoints require `Authorization: Bearer <jwt_token>` header except:
- `POST /auth/login`
- `POST /auth/register`
- `POST /auth/verify-otp`
- `GET /health`

---

## Orders (Unified - tất cả 4 service types)

| Method | Path | Description |
|--------|------|-------------|
| POST | /orders | Tạo đơn hàng (ride/food/grocery/designated) |
| GET | /orders/:id | Lấy thông tin đơn |
| PUT | /orders/:id/status | Cập nhật trạng thái |
| POST | /orders/:id/cancel | Hủy đơn |
| GET | /orders/history | Lịch sử đơn hàng |
| POST | /orders/estimate | Ước tính giá |

### Grocery-specific
| Method | Path | Description |
|--------|------|-------------|
| POST | /orders/:id/substitution | Tài xế đề xuất thay thế |
| PUT | /orders/:id/substitution/:itemId | Khách xác nhận thay thế |
| POST | /orders/:id/receipt | Upload hóa đơn chợ |

### Designated Driver-specific
| Method | Path | Description |
|--------|------|-------------|
| POST | /orders/:id/inspection | Kiểm tra xe (pickup/dropoff) |

---

## Merchants (Nhà hàng, Cửa hàng)

| Method | Path | Description |
|--------|------|-------------|
| GET | /merchants/nearby | Tìm quán/cửa hàng gần |
| GET | /merchants/:id | Thông tin merchant |
| GET | /merchants/:id/menu | Xem menu |
| GET | /merchants/search | Tìm kiếm |
| POST | /merchants/:id/orders/:orderId/confirm | Xác nhận đơn |
| PUT | /merchants/:id/orders/:orderId/status | Cập nhật trạng thái chuẩn bị |

### Merchant Management
| Method | Path | Description |
|--------|------|-------------|
| POST | /merchants | Đăng ký merchant |
| PUT | /merchants/:id | Cập nhật thông tin |
| POST | /merchants/:id/menu | Thêm món |
| PUT | /merchants/:id/menu/:itemId | Sửa món |
| PATCH | /merchants/:id/menu/:itemId/availability | Bật/tắt món |

---

## Rides (Legacy - redirect to Orders)
| Method | Path | Description |
|--------|------|-------------|
| POST | /rides | → Redirect to POST /orders (service_type=ride) |

## Drivers
| Method | Path | Description |
|--------|------|-------------|
| PUT | /drivers/status | Online/Offline |
| PUT | /drivers/capabilities | Cập nhật service types |
| GET | /drivers/:id/earnings | Thu nhập |

## Users
| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/login | Đăng nhập (OTP) |
| POST | /auth/register | Đăng ký |
| GET | /users/profile | Profile |

## Payments
| Method | Path | Description |
|--------|------|-------------|
| POST | /payments | Tạo thanh toán |
| GET | /wallet/balance | Số dư ví |
| POST | /wallet/topup | Nạp tiền |
