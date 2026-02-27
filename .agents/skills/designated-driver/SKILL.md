---
name: Designated Driver Service
description: Hướng dẫn triển khai chức năng lái xe hộ - vehicle inspection, shadow driver, night surcharge.
---

# Designated Driver Service

## Khi nào dùng skill này?
- Triển khai chức năng lái xe hộ
- Xử lý vehicle inspection (kiểm tra xe trước/sau)
- Shadow driver mode (solo vs duo)

## Luồng chính
```
Khách đặt lái xe hộ (vị trí xe + điểm đến)
    → Tìm tài xế có GPLX ô tô gần vị trí xe
    → Tài xế đến → Kiểm tra xe + chụp 4 ảnh
    → Lái xe khách đến điểm trả
    → Bàn giao xe + kiểm tra lại → Thanh toán
```

## State Machine
```
CREATED → DRIVER_ASSIGNED → DRIVER_ARRIVING → ARRIVED
→ VEHICLE_INSPECTION → DRIVING → ARRIVED_DESTINATION
→ VEHICLE_HANDOVER → COMPLETED → PAID
```

## Shadow Driver Modes
- **Solo**: Tài xế có xe gấp → gấp cất cốp → lái xe khách → đến nơi, lấy xe gấp ra về
- **Duo**: 2 tài xế đi cùng → 1 lái xe khách, 1 chạy xe máy theo → chở tài xế về

## Vehicle Inspection (Bắt buộc)
Chụp 4 ảnh: trước, sau, trái, phải + ghi nhận:
- Km đồng hồ, mức xăng
- Trầy xước có sẵn
→ Phòng tránh tranh chấp hư hại

## Key Points
1. **Chỉ tài xế có GPLX ô tô** mới nhận cuốc
2. **Giá cao hơn ride thông thường** (×1.5 rate/km)
3. **Phụ thu đêm khuya** 22h-6h: +30%
4. Vehicle inspection bắt buộc cả pickup và dropoff

## Tính giá
```
Total = Base fare (cao) + (Km × Rate × 1.5) + (Min × Rate × 1.2)
      + Night surcharge + Shadow driver fee - Discount
```

## References
- Architecture: [docs/architecture/SERVICES.md](../../docs/architecture/SERVICES.md)
