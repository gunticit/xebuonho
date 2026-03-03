import 'package:flutter/material.dart';
import '../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Chính sách bảo mật', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Chính sách bảo mật', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          Text('Cập nhật: 04/03/2026', style: TextStyle(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 20),

          _buildSection('1. Giới thiệu',
            'Xebuonho ("chúng tôi") cam kết bảo vệ quyền riêng tư của bạn. '
            'Chính sách này mô tả cách chúng tôi thu thập, sử dụng, và bảo vệ thông tin cá nhân '
            'khi bạn sử dụng ứng dụng Xebuonho Rider ("Ứng dụng").'),

          _buildSection('2. Thông tin chúng tôi thu thập', null, bullets: [
            '📍 Vị trí — Để tìm tài xế gần bạn, hiển thị bản đồ, và tính cước phí.',
            '👤 Thông tin cá nhân — Tên, số điện thoại, email để tạo tài khoản và liên lạc.',
            '💳 Thông tin thanh toán — Phương thức thanh toán (không lưu số thẻ trực tiếp).',
            '📱 Thông tin thiết bị — Loại thiết bị, phiên bản OS để cải thiện app.',
            '📊 Dữ liệu sử dụng — Lịch sử chuyến đi, đánh giá, tương tác trong app.',
          ]),

          _buildSection('3. Cách chúng tôi sử dụng dữ liệu', null, bullets: [
            'Cung cấp dịch vụ đặt xe, giao đồ ăn, và các dịch vụ liên quan.',
            'Kết nối bạn với tài xế phù hợp nhất dựa trên vị trí.',
            'Xử lý thanh toán và gửi hóa đơn.',
            'Cải thiện chất lượng dịch vụ và trải nghiệm người dùng.',
            'Gửi thông báo về chuyến đi, khuyến mãi (có thể tắt trong Cài đặt).',
            'Đảm bảo an toàn — phát hiện gian lận, hỗ trợ khẩn cấp.',
          ]),

          _buildSection('4. Chia sẻ dữ liệu', null, bullets: [
            '🚗 Tài xế — Chỉ chia sẻ tên, điểm đón/trả khi có chuyến đi.',
            '💰 Đối tác thanh toán — MoMo, ZaloPay, VNPay để xử lý giao dịch.',
            '🗺️ Dịch vụ bản đồ — OpenStreetMap để hiển thị bản đồ và tìm đường.',
            '⚖️ Cơ quan pháp luật — Khi có yêu cầu hợp pháp từ cơ quan chức năng.',
          ]),

          _buildSection('5. Bảo mật dữ liệu',
            'Chúng tôi sử dụng mã hóa SSL/TLS cho mọi giao tiếp. '
            'Dữ liệu được lưu trữ trên máy chủ an toàn với kiểm soát truy cập nghiêm ngặt. '
            'Mật khẩu được hash bằng thuật toán bcrypt. '
            'Token xác thực (JWT) có thời hạn giới hạn.'),

          _buildSection('6. Quyền của bạn', null, bullets: [
            '✏️ Chỉnh sửa thông tin cá nhân trong mục Hồ sơ.',
            '📥 Yêu cầu xuất dữ liệu cá nhân (liên hệ support).',
            '🗑️ Xóa tài khoản và toàn bộ dữ liệu (Cài đặt > Xóa tài khoản).',
            '🔔 Tắt thông báo marketing trong Cài đặt.',
            '📍 Thu hồi quyền truy cập vị trí trong cài đặt thiết bị.',
          ]),

          _buildSection('7. Lưu trữ dữ liệu',
            'Dữ liệu cá nhân được lưu trữ trong suốt thời gian bạn sử dụng dịch vụ. '
            'Sau khi xóa tài khoản, dữ liệu sẽ bị xóa trong vòng 30 ngày, '
            'ngoại trừ dữ liệu cần giữ theo yêu cầu pháp luật (tối đa 5 năm).'),

          _buildSection('8. Cookie & Tracking',
            'Ứng dụng không sử dụng cookie. Chúng tôi không theo dõi bạn trên các ứng dụng hoặc website khác. '
            'Analytics được sử dụng ở dạng ẩn danh để cải thiện dịch vụ.'),

          _buildSection('9. Trẻ em',
            'Dịch vụ của chúng tôi không dành cho người dưới 18 tuổi. '
            'Chúng tôi không cố ý thu thập dữ liệu từ trẻ em. '
            'Nếu phát hiện vi phạm, vui lòng liên hệ để chúng tôi xử lý ngay.'),

          _buildSection('10. Thay đổi chính sách',
            'Chúng tôi có thể cập nhật chính sách này. Bạn sẽ được thông báo '
            'qua app khi có thay đổi quan trọng. Tiếp tục sử dụng app sau thay đổi '
            'đồng nghĩa với việc bạn chấp nhận chính sách mới.'),

          const SizedBox(height: 16),

          // Contact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📧 Liên hệ về bảo mật', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 8),
                Text('Email: privacy@xebuonho.vn', style: TextStyle(fontSize: 13, color: AppColors.blue)),
                Text('Hotline: 1900-xxxx (8h-22h)', style: TextStyle(fontSize: 13, color: AppColors.text2)),
                Text('Địa chỉ: TP. Hồ Chí Minh, Việt Nam', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String? content, {List<String>? bullets}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 8),
          if (content != null)
            Text(content, style: TextStyle(fontSize: 14, color: AppColors.text2, height: 1.6)),
          if (bullets != null)
            ...bullets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(b, style: TextStyle(fontSize: 14, color: AppColors.text2, height: 1.5)),
            )),
        ],
      ),
    );
  }
}

// ========== Terms of Service ==========
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Điều khoản sử dụng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Điều khoản sử dụng', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          Text('Cập nhật: 04/03/2026', style: TextStyle(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 20),

          _buildTerm('1. Chấp nhận điều khoản',
            'Bằng việc tải, cài đặt, và sử dụng ứng dụng Xebuonho, bạn đồng ý tuân thủ các điều khoản này.'),
          _buildTerm('2. Dịch vụ',
            'Xebuonho cung cấp nền tảng kết nối hành khách với tài xế. '
            'Chúng tôi không phải là công ty vận tải. Tài xế là đối tác độc lập.'),
          _buildTerm('3. Tài khoản',
            'Bạn phải từ 18 tuổi trở lên để sử dụng. Mỗi người chỉ được 1 tài khoản. '
            'Bạn chịu trách nhiệm bảo mật thông tin đăng nhập.'),
          _buildTerm('4. Thanh toán',
            'Giá cước được hiển thị trước khi đặt xe. Phí có thể thay đổi do phụ phí giờ cao điểm, '
            'thời tiết, hoặc tuyến đường. Bạn đồng ý thanh toán đầy đủ cho mỗi chuyến đi.'),
          _buildTerm('5. Hủy chuyến',
            'Hủy chuyến miễn phí trong 2 phút đầu. Sau đó có thể áp dụng phí hủy.'),
          _buildTerm('6. Hành vi người dùng',
            'Không được quấy rối, đe dọa tài xế. Không hút thuốc, mang chất cấm trên xe. '
            'Vi phạm nghiêm trọng sẽ bị khóa tài khoản vĩnh viễn.'),
          _buildTerm('7. An toàn',
            'Luôn thắt dây an toàn. Kiểm tra biển số trước khi lên xe. '
            'Sử dụng tính năng SOS trong trường hợp khẩn cấp.'),
          _buildTerm('8. Giới hạn trách nhiệm',
            'Xebuonho nỗ lực cung cấp dịch vụ tốt nhất nhưng không đảm bảo dịch vụ luôn sẵn có, '
            'không gián đoạn, hoặc không có lỗi.'),
          _buildTerm('9. Chấm dứt',
            'Chúng tôi có quyền đình chỉ hoặc chấm dứt tài khoản nếu vi phạm điều khoản. '
            'Bạn có thể xóa tài khoản bất cứ lúc nào.'),
          _buildTerm('10. Luật áp dụng',
            'Điều khoản này được điều chỉnh bởi pháp luật Việt Nam. '
            'Mọi tranh chấp sẽ được giải quyết tại tòa án có thẩm quyền tại TP. Hồ Chí Minh.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTerm(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(fontSize: 14, color: AppColors.text2, height: 1.6)),
        ],
      ),
    );
  }
}
