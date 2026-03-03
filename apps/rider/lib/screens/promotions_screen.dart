import 'package:flutter/material.dart';
import '../config/theme.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Khuyến mãi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Promo code input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Nhập mã khuyến mãi',
                        prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppColors.text3, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.blue, borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Áp dụng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active promos
            const Text('Đang có hiệu lực', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            _buildPromo('🎉', 'Giảm 30% chuyến xe máy', 'Áp dụng cho chuyến dưới 5km', 'BIKE30', 'Còn 3 ngày', AppColors.green, true),
            _buildPromo('🍔', 'Free ship đồ ăn', 'Đơn từ 50.000đ', 'FREESHIP', 'Còn 7 ngày', AppColors.orange, true),

            const SizedBox(height: 24),
            const Text('Khám phá', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            _buildPromo('🚗', 'Giảm 50k ô tô', 'Chuyến đầu tiên trong tuần', 'CAR50K', 'Còn 14 ngày', AppColors.blue, false),
            _buildPromo('⭐', 'Thưởng 2x điểm', 'Tích điểm gấp đôi mỗi chuyến', 'DOUBLE', 'Còn 30 ngày', AppColors.purple, false),
            _buildPromo('🛒', 'Giảm 20% đi chợ hộ', 'Đơn từ 100.000đ trở lên', 'MARKET20', 'Còn 5 ngày', AppColors.cyan, false),

            const SizedBox(height: 24),
            const Text('Đã hết hạn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text3)),
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.5,
              child: _buildPromo('💤', 'Giảm 15% xe máy', 'Đã hết hạn 01/03', 'OLD15', 'Hết hạn', AppColors.text3, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromo(String emoji, String title, String desc, String code, String expiry, Color color, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? color.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bg3, borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 8),
                    Text(expiry, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          if (active) const Icon(Icons.check_circle, color: AppColors.green, size: 20),
        ],
      ),
    );
  }
}
