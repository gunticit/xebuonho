---
name: Grocery Shopping Service
description: Hướng dẫn triển khai chức năng đi chợ hộ - shopping list, product substitution, receipt upload.
---

# Grocery Shopping Service

## Khi nào dùng skill này?
- Triển khai chức năng đi chợ hộ
- Xử lý shopping list, thay thế sản phẩm
- Upload hóa đơn + tính giá thực tế

## Luồng chính
```
Khách tạo danh sách mua → Hệ thống ước tính giá
    → Tìm tài xế gần chợ/siêu thị
    → Tài xế đến chợ → Mua sắm theo list
    → Sản phẩm hết? → Đề xuất thay thế → Khách xác nhận
    → Mua xong → Chụp hóa đơn → Upload
    → Tính giá thực tế → Giao hàng → Thanh toán
```

## State Machine
```
CREATED → DRIVER_ASSIGNED → DRIVER_TO_STORE → AT_STORE
→ SHOPPING → (ITEM_SUBSTITUTION ↔ SHOPPING) → SHOPPING_DONE
→ RECEIPT_UPLOADED → DELIVERING → DELIVERED → PAID
```

## Key Points
1. Tài xế vừa là **người mua** vừa là **shipper**
2. **Thay thế sản phẩm**: WebSocket push realtime cho khách xác nhận
3. **Hóa đơn bắt buộc** - minh bạch giá
4. Giá thực tế có thể **khác** giá ước tính
5. `max_grocery_value` giới hạn số tiền tài xế ứng ra mua

## Tính giá
```
Total = Tiền hàng thực tế (hóa đơn) + Service fee (15-20% min 20k) + Delivery fee
```

## References
- Architecture: [docs/architecture/SERVICES.md](../../docs/architecture/SERVICES.md)
