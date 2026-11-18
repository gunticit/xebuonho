import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/app_icons.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_avatar.dart';

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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GradientAvatar(
                          name: auth.userName,
                          size: AvatarSize.medium,
                          showOnline: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.userName.isNotEmpty ? auth.userName : 'Khách hàng',
                                style: AppTextStyles.heading3.copyWith(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                auth.userPhone.isNotEmpty ? auth.userPhone : 'Chưa cập nhật',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(AppIcons.forward, color: AppColors.text3, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(AppIcons.star, size: 12, color: AppColors.green),
                          const SizedBox(width: 4),
                          Text(
                            auth.userRole == 'rider' ? 'Khách hàng' : (auth.userRole == 'driver' ? 'Đối tác Tài xế' : auth.userRole),
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.green),
                          ),
                        ],
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
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: auth.isDriver
                      ? AppColors.blue.withValues(alpha: 0.4)
                      : AppColors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  IconContainer(
                    icon: auth.isDriver ? AppIcons.profile : AppIcons.car,
                    color: auth.isDriver ? AppColors.blue : AppColors.orange,
                    size: 38,
                    iconSize: 20,
                    borderRadius: AppRadius.sm,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isDriver ? 'Chế độ Tài xế' : 'Chạy xe kiếm thu nhập?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: auth.isDriver ? AppColors.blue : AppColors.orange,
                          ),
                        ),
                        Text(
                          auth.isDriver ? 'Bấm để về giao diện Khách' : 'Chuyển sang Chế độ Tài xế',
                          style: AppTextStyles.caption,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
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
                  _buildMenuItem(context, AppIcons.home, 'Trang chủ', '/home', isActive: true),
                  _buildMenuItem(context, AppIcons.car, 'Bàn làm việc Tài xế', '/driver'),
                  _buildMenuItem(context, AppIcons.activities, 'Hoạt động & Đơn hàng', '/activities'),
                  _buildMenuItem(context, AppIcons.schedule, 'Đặt lịch chuyến', '/schedule'),
                  _buildMenuItem(context, AppIcons.notifications, 'Thông báo', '/notifications', badge: '3'),
                  if (auth.isAdmin) ...[
                    _buildDivider(),
                    _buildSectionTitle('QUẢN TRỊ'),
                    _buildMenuItem(context, AppIcons.shield, 'Duyệt hồ sơ tài xế (KYC)', '/admin'),
                  ],
                  _buildDivider(),
                  _buildSectionTitle('DỊCH VỤ'),
                  _buildMenuItem(context, AppIcons.bike, 'Xe máy', '/search'),
                  _buildMenuItem(context, AppIcons.car, 'Ô tô', '/search'),
                  _buildMenuItem(context, AppIcons.food, 'Đồ ăn', '/food'),
                  _buildMenuItem(context, AppIcons.grocery, 'Đi chợ hộ', '/grocery'),
                  _buildMenuItem(context, AppIcons.designatedDriver, 'Lái xe hộ', '/designated-driver'),
                  _buildMenuItem(context, AppIcons.delivery, 'Giao hàng Express', '/delivery'),
                  _buildDivider(),
                  _buildSectionTitle('TÀI KHOẢN'),
                  _buildMenuItem(context, AppIcons.profile, 'Thông tin cá nhân', '/profile'),
                  _buildMenuItem(context, AppIcons.dropoff, 'Địa chỉ đã lưu', '/saved-addresses'),
                  _buildMenuItem(context, AppIcons.creditCard, 'Thanh toán & Ví', '/payment'),
                  _buildMenuItem(context, AppIcons.voucher, 'Khuyến mãi', '/promotions', badge: '2'),
                  _buildMenuItem(context, AppIcons.chat, 'Chat hỗ trợ', '/chat'),
                  _buildMenuItem(context, AppIcons.support, 'Hỗ trợ khách hàng', '/support'),
                  _buildMenuItem(context, AppIcons.settings, 'Cài đặt', '/settings'),
                  _buildDivider(),
                  _buildSectionTitle('PHÁP LÝ'),
                  _buildMenuItem(context, AppIcons.privacy, 'Chính sách bảo mật', '/privacy'),
                  _buildMenuItem(context, AppIcons.terms, 'Điều khoản sử dụng', '/terms'),
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
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(AppIcons.logout, color: AppColors.red, size: 18),
                      const SizedBox(width: 8),
                      Text('Đăng xuất', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700, color: AppColors.red)),
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
      {bool isActive = false, String? badge}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.blueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? AppColors.blue : AppColors.text3),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.blue : AppColors.text,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(badge, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Divider(color: AppColors.border, height: 1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 16, 4),
      child: Text(
        title,
        style: AppTextStyles.caption.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
      ),
    );
  }
}
