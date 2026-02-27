---
name: Food Delivery Service
description: Hướng dẫn triển khai chức năng đặt đồ ăn - quản lý nhà hàng, menu, đơn hàng, tính giá, và giao hàng.
---

# Food Delivery Service

## Khi nào dùng skill này?
- Triển khai chức năng đặt đồ ăn
- Quản lý merchant (nhà hàng) và menu
- Xử lý luồng 3 bên: Khách → Nhà hàng → Tài xế

## Luồng chính
```
Khách chọn nhà hàng → Chọn món → Đặt đơn
    → Nhà hàng xác nhận → Bắt đầu nấu
    → Hệ thống tìm tài xế gần nhà hàng
    → Tài xế đến quán → Lấy đồ → Giao cho khách
```

## State Machine
```
PLACED → MERCHANT_CONFIRMED → PREPARING → READY_FOR_PICKUP
                            → SEARCHING_DRIVER → DRIVER_ASSIGNED
DRIVER_TO_MERCHANT → AT_MERCHANT → PICKED_UP → DELIVERING → DELIVERED → PAID
```

## Key Points
1. **Tìm tài xế gần NHÀ HÀNG**, không gần khách
2. Tìm tài xế **trễ 5-10 phút** sau khi nhà hàng xác nhận (để đồ gần xong mới gọi)
3. **ETA = prep time + pickup time + delivery time**
4. Menu items có `options` (size, topping) dưới dạng JSONB

## Tính giá
```
Total = Giá món + Packaging fee + Delivery fee × Surge - Discount
Commission = Total × merchant.commission_rate (15-30%)
```

## References
- Architecture: [docs/architecture/SERVICES.md](../../docs/architecture/SERVICES.md)
- Proto: [proto/order/](../../proto/order/), [proto/merchant/](../../proto/merchant/)
