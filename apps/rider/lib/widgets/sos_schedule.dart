import 'package:flutter/material.dart';
import '../config/theme.dart';

class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showSosDialog(context),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.redBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.5), width: 2),
        ),
        child: const Center(
          child: Text('🆘', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🚨', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Khẩn cấp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSosOption(context, '📞', 'Gọi 113 (Công an)', 'Gọi ngay'),
            _buildSosOption(context, '🚑', 'Gọi 115 (Cấp cứu)', 'Gọi ngay'),
            _buildSosOption(context, '📍', 'Chia sẻ vị trí', 'Gửi cho người thân'),
            _buildSosOption(context, '🔴', 'Ghi âm khẩn cấp', 'Bắt đầu ghi'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: AppColors.text3)),
          ),
        ],
      ),
    );
  }

  Widget _buildSosOption(BuildContext context, String emoji, String title, String action) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title - Đang xử lý...'), backgroundColor: AppColors.red),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg3, borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                  Text(action, style: const TextStyle(fontSize: 11, color: AppColors.red)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.red, size: 18),
          ],
        ),
      ),
    );
  }
}

class SchedulePicker extends StatelessWidget {
  const SchedulePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Đặt lịch đón', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 20),

          // Time options
          Row(
            children: [
              _buildTimeOption('Ngay bây giờ', '🕐', true),
              const SizedBox(width: 10),
              _buildTimeOption('Hẹn giờ', '📅', false),
            ],
          ),
          const SizedBox(height: 16),

          // Quick picks
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _buildQuickPick('30 phút nữa'),
              _buildQuickPick('1 giờ nữa'),
              _buildQuickPick('2 giờ nữa'),
              _buildQuickPick('Ngày mai 8:00'),
              _buildQuickPick('Ngày mai 18:00'),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Xác nhận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _buildTimeOption(String label, String emoji, bool selected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueBg : AppColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.blue : AppColors.text2)),
          ],
        ),
      ),
    );
  }

  static Widget _buildQuickPick(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg3, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
    );
  }
}
