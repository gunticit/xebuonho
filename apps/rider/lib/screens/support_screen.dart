import 'package:flutter/material.dart';
import '../config/theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Hỗ trợ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick call
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.green.withValues(alpha: 0.15), AppColors.blue.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('📞', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  const Text('Hotline hỗ trợ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 4),
                  const Text('1900 6868', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green)),
                  const SizedBox(height: 4),
                  Text('Hoạt động 24/7', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FAQ
            const Text('Câu hỏi thường gặp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            _buildFAQ('Làm sao để hủy chuyến?', 'Bạn có thể hủy chuyến trước khi tài xế đến. Vào Lịch sử chuyến > Chọn chuyến > Hủy chuyến.'),
            _buildFAQ('Quên đồ trên xe?', 'Liên hệ hotline 1900 6868 hoặc vào Lịch sử chuyến > Liên hệ tài xế.'),
            _buildFAQ('Tại sao giá cao hơn bình thường?', 'Vào giờ cao điểm (7-9h, 17-19h), giá có thể tăng do nhu cầu cao.'),
            _buildFAQ('Làm sao đổi phương thức thanh toán?', 'Vào Menu > Thanh toán > Chọn phương thức mới.'),
            _buildFAQ('Tài xế không đến?', 'Nếu tài xế không đến sau 10 phút, chuyến sẽ tự động hủy và bạn không bị tính phí.'),

            const SizedBox(height: 24),
            const Text('Liên hệ khác', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            _buildContact(Icons.email_outlined, 'Email', 'support@xebuonho.vn', AppColors.blue),
            _buildContact(Icons.chat_bubble_outline, 'Chat trực tuyến', 'Đang hoạt động', AppColors.green),
            _buildContact(Icons.facebook, 'Facebook', 'fb.com/xebuonho', AppColors.blue),
            _buildContact(Icons.language, 'Zalo OA', 'zalo.me/xebuonho', AppColors.cyan),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
        iconColor: AppColors.text3,
        collapsedIconColor: AppColors.text3,
        children: [
          Text(answer, style: const TextStyle(fontSize: 13, color: AppColors.text3, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildContact(IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
        ],
      ),
    );
  }
}
