import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Drawer(
      backgroundColor: AppColors.bg2,
      child: SafeArea(
        child: Column(
          children: [
            // ========== User Header ==========
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.blue, AppColors.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(auth.userName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                              const SizedBox(height: 2),
                              Text(auth.userPhone,
                                style: const TextStyle(fontSize: 13, color: AppColors.text3)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.text3, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⭐ ${auth.userRole == 'rider' ? 'Khách hàng' : auth.userRole}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ========== Role Switcher Banner ==========
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: auth.isDriver ? AppColors.blueBg : AppColors.orangeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: auth.isDriver
                      ? AppColors.blue.withValues(alpha: 0.4)
                      : AppColors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Text(auth.isDriver ? '🙋‍♂️' : '🚕', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isDriver ? 'Đang ở Chế độ Tài xế' : 'Chạy xe kiếm thêm thu nhập?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: auth.isDriver ? AppColors.blue : AppColors.orange,
                          ),
                        ),
                        Text(
                          auth.isDriver ? 'Bấm để về giao diện Khách' : 'Chuyển sang Chế độ Tài xế',
                          style: const TextStyle(fontSize: 11, color: AppColors.text3),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (auth.isDriver) {
                        auth.switchRole('rider');
                        Navigator.pushReplacementNamed(context, '/home');
                      } else {
                        auth.switchRole('driver');
                        Navigator.pushReplacementNamed(context, '/driver');
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: auth.isDriver ? AppColors.blue : AppColors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Đổi vai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // ========== Menu Items ==========
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuItem(context, Icons.home_outlined, 'Trang chủ', '/home', isActive: true),
                  _buildMenuItem(context, Icons.drive_eta, 'Bàn làm việc Tài xế', '/driver', emoji: '🚕'),
                  _buildMenuItem(context, Icons.receipt_long, 'Hoạt động & Đơn hàng', '/activities'),
                  _buildMenuItem(context, Icons.schedule, 'Đặt lịch chuyến', '/schedule', emoji: '📅'),
                  _buildMenuItem(context, Icons.notifications_outlined, 'Thông báo', '/notifications', badge: '3'),
                  _buildDivider(),
                  _buildSectionTitle('DỊCH VỤ'),
                  _buildMenuItem(context, Icons.two_wheeler, 'Xe máy', '/search', emoji: '🏍️'),
                  _buildMenuItem(context, Icons.directions_car, 'Ô tô', '/search', emoji: '🚗'),
                  _buildMenuItem(context, Icons.fastfood, 'Đồ ăn', '/food', emoji: '🍔'),
                  _buildMenuItem(context, Icons.shopping_basket, 'Đi chợ hộ', '/grocery', emoji: '🛒'),
                  _buildMenuItem(context, Icons.shield, 'Lái xe hộ', '/designated-driver', emoji: '🚙'),
                  _buildMenuItem(context, Icons.local_shipping, 'Giao hàng Express', '/delivery', emoji: '📦'),
                  _buildDivider(),
                  _buildSectionTitle('TÀI KHOẢN'),
                  _buildMenuItem(context, Icons.person_outline, 'Thông tin cá nhân', '/profile'),
                  _buildMenuItem(context, Icons.location_on_outlined, 'Địa chỉ đã lưu', '/saved-addresses'),
                  _buildMenuItem(context, Icons.payment, 'Thanh toán', '/payment'),
                  _buildMenuItem(context, Icons.card_giftcard, 'Khuyến mãi', '/promotions', badge: '2'),
                  _buildMenuItem(context, Icons.chat_bubble_outline, 'Chat hỗ trợ', '/chat'),
                  _buildMenuItem(context, Icons.support_agent, 'Hỗ trợ', '/support'),
                  _buildMenuItem(context, Icons.settings_outlined, 'Cài đặt', '/settings'),
                  _buildDivider(),
                  _buildSectionTitle('PHÁP LÝ'),
                  _buildMenuItem(context, Icons.privacy_tip_outlined, 'Chính sách bảo mật', '/privacy'),
                  _buildMenuItem(context, Icons.description_outlined, 'Điều khoản sử dụng', '/terms'),
                ],
              ),
            ),

            // ========== Logout ==========
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: GestureDetector(
                onTap: () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.redBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: AppColors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Đăng xuất', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String? route,
      {bool isActive = false, String? badge, String? emoji}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.blueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (emoji != null)
              SizedBox(width: 24, child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))))
            else
              Icon(icon, size: 20, color: isActive ? AppColors.blue : AppColors.text3),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                style: TextStyle(
                  fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? AppColors.blue : AppColors.text,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Divider(color: AppColors.border, height: 1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 16, 4),
      child: Text(title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
    );
  }
}
