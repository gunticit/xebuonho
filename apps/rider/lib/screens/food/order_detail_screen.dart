import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Chi tiết đơn hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== Status ==========
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.greenBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Đã giao thành công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.green)),
                Text('Đơn #XBN-240304-001', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                Text('04/03/2026 — 12:34', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Restaurant ==========
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('🍜', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Phở Thìn Bờ Hồ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                Row(children: [
                  Text('⭐ 4.8', style: TextStyle(fontSize: 12, color: AppColors.orange)),
                  Text('  •  📍 1.2 km', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ]),
              ])),
              Icon(Icons.chevron_right, color: AppColors.text3, size: 20),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Items ==========
          _buildSection('🛒 Các món đã đặt'),
          _buildItemRow('2x', 'Phở tái nạm', 110000, fmt),
          _buildItemRow('1x', 'Phở gà', 48000, fmt),
          _buildItemRow('2x', 'Nước chanh', 30000, fmt),
          const SizedBox(height: 16),

          // ========== Delivery Info ==========
          _buildSection('📍 Giao đến'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Text('🏠', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nhà', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text('123 Nguyễn Huệ, Q.1, TP.HCM', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Driver ==========
          _buildSection('🏍️ Tài xế'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('T', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Trần Văn Tài', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text('⭐ 4.9  •  59F1-12345', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text('⭐', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('Đã đánh giá 5 sao', style: TextStyle(fontSize: 11, color: AppColors.orange, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Payment ==========
          _buildSection('💰 Thanh toán'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              _buildPriceRow('Tạm tính', '${fmt.format(188000)}đ'),
              _buildPriceRow('Phí giao hàng', '${fmt.format(15000)}đ'),
              _buildPriceRow('Giảm giá', '-${fmt.format(20000)}đ', isGreen: true),
              const Divider(color: AppColors.border, height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tổng cộng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                Text('${fmt.format(183000)}đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.orange)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Text('👛', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('Ví Xebuonho', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(6)),
                  child: Text('Đã thanh toán', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green)),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // ========== Actions ==========
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/share-bill'),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Text('🧾 Chia bill', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.purple))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/food'),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.green, Color(0xFF2ECC71)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: Text('🔄 Đặt lại', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
    );
  }

  Widget _buildItemRow(String qty, String name, int price, NumberFormat fmt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(qty, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: TextStyle(fontSize: 14, color: AppColors.text))),
        Text('${fmt.format(price)}đ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
      ]),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.text2)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isGreen ? AppColors.green : AppColors.text)),
      ]),
    );
  }
}
