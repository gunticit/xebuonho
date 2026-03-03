import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'package:intl/intl.dart';

class RideDetailScreen extends StatelessWidget {
  const RideDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Chi tiết chuyến đi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Hỗ trợ', style: TextStyle(color: AppColors.blue, fontSize: 13))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Text('✅', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hoàn thành', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.green)),
                      Text('04/03/2026 - 14:30', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Route
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildRoutePoint('🟢', 'Điểm đón', 'Landmark 81, Bình Thạnh', '14:00'),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Column(
                      children: List.generate(3, (_) => Container(
                        width: 2, height: 8, margin: const EdgeInsets.symmetric(vertical: 2),
                        color: AppColors.border,
                      )),
                    ),
                  ),
                  _buildRoutePoint('🔴', 'Điểm trả', 'Bitexco Tower, Q.1', '14:28'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Map preview placeholder
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.bg3, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🗺️', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 4),
                    Text('Xem bản đồ tuyến đường', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Driver info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.greenBg, borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🧑', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nguyễn Văn B', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                        Text('⭐ 4.9 • Honda Wave • 59B1-12345', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(10)),
                    child: const Text('🏍️ Xe máy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blue)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fare breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chi tiết giá', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 12),
                  _buildFareLine('Giá cước cơ bản', fmt.format(28000)),
                  _buildFareLine('Phí nền tảng', fmt.format(2000)),
                  _buildFareLine('Phí giờ cao điểm', fmt.format(5000)),
                  _buildFareLine('Khuyến mãi BIKE30', '-${fmt.format(8400)}', isDiscount: true),
                  const Divider(color: AppColors.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng cộng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                      Text('${fmt.format(26600)}đ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('💵', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Tiền mặt', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trip stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('7.2 km', 'Quãng đường'),
                  Container(width: 1, height: 36, color: AppColors.border),
                  _buildStat('28 phút', 'Thời gian'),
                  Container(width: 1, height: 36, color: AppColors.border),
                  _buildStat('15.4 km/h', 'Tốc độ TB'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: _buildActionBtn('📄 Hóa đơn', AppColors.blue, () {}),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionBtn('⚠️ Báo cáo', AppColors.orange, () {}),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePoint(String dot, String label, String address, String time) {
    return Row(
      children: [
        Text(dot, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3)),
              Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
      ],
    );
  }

  Widget _buildFareLine(String label, String amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          Text('${amount}đ', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: isDiscount ? AppColors.green : AppColors.text,
          )),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
      ],
    );
  }

  Widget _buildActionBtn(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
      ),
    );
  }
}
