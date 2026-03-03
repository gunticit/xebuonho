import 'package:flutter/material.dart';
import '../config/theme.dart';

/// First-launch consent dialog — required by Apple & Google
class ConsentDialog extends StatefulWidget {
  final VoidCallback onAccept;
  const ConsentDialog({super.key, required this.onAccept});

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _locationAccepted = false;
  bool _dataAccepted = false;
  bool _termsAccepted = false;

  bool get _allAccepted => _locationAccepted && _dataAccepted && _termsAccepted;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Text('🛡️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('Quyền riêng tư & Dữ liệu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 6),
            Text(
              'Để cung cấp dịch vụ tốt nhất, chúng tôi cần một số quyền truy cập.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.text3, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Location permission
            _buildConsentItem(
              emoji: '📍',
              title: 'Truy cập vị trí',
              description: 'Tìm tài xế gần bạn, hiển thị bản đồ, và tính cước phí chính xác.',
              value: _locationAccepted,
              onChanged: (v) => setState(() => _locationAccepted = v!),
            ),
            const SizedBox(height: 12),

            // Data collection
            _buildConsentItem(
              emoji: '📊',
              title: 'Thu thập dữ liệu',
              description: 'Lưu lịch sử chuyến đi, đánh giá, và cải thiện dịch vụ. Dữ liệu được mã hóa.',
              value: _dataAccepted,
              onChanged: (v) => setState(() => _dataAccepted = v!),
            ),
            const SizedBox(height: 12),

            // Terms & Policy
            _buildConsentItem(
              emoji: '📋',
              title: 'Điều khoản & Chính sách',
              description: 'Tôi đã đọc và đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v!),
              links: true,
            ),
            const SizedBox(height: 8),

            // View links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/terms'),
                  child: Text('Điều khoản', style: TextStyle(fontSize: 12, color: AppColors.blue, decoration: TextDecoration.underline)),
                ),
                Text('  •  ', style: TextStyle(color: AppColors.text3)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                  child: Text('Chính sách bảo mật', style: TextStyle(fontSize: 12, color: AppColors.blue, decoration: TextDecoration.underline)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Accept button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _allAccepted ? () {
                  Navigator.pop(context);
                  widget.onAccept();
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  disabledBackgroundColor: AppColors.bg3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _allAccepted ? 'Đồng ý & Tiếp tục' : 'Vui lòng chấp nhận tất cả',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: _allAccepted ? Colors.white : AppColors.text3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentItem({
    required String emoji,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool links = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? AppColors.greenBg : AppColors.bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? AppColors.green.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: AppColors.text3, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }
}
