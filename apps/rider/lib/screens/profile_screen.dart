import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/app_icons.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameCtrl = TextEditingController(text: auth.userName);
    _phoneCtrl = TextEditingController(text: auth.userPhone);
    _emailCtrl = TextEditingController(text: auth.userEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: Text('Thông tin cá nhân', style: AppTextStyles.heading3),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(
              _editing ? 'Hủy' : 'Sửa',
              style: AppTextStyles.body1.copyWith(
                color: AppColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Modern Avatar with gradient ring
            Center(
              child: Stack(
                children: [
                  GradientAvatar(
                    name: auth.userName,
                    size: AvatarSize.large,
                    showOnline: true,
                  ),
                  if (_editing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2.5),
                          boxShadow: AppShadows.subtle,
                        ),
                        child: const Icon(AppIcons.camera, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.verified, size: 14, color: AppColors.green),
                  const SizedBox(width: 6),
                  Text(
                    auth.userRole == 'rider' ? 'Khách hàng' : (auth.userRole == 'driver' ? 'Đối tác Tài xế' : auth.userRole),
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Fields
            _buildField('Họ và tên', _nameCtrl, AppIcons.profile, _editing),
            _buildField('Số điện thoại', _phoneCtrl, AppIcons.call, false),
            _buildField('Email', _emailCtrl, Icons.email_rounded, _editing),
            const SizedBox(height: 16),

            // Modern Stats Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppGradients.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.subtle,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('27', 'Chuyến đi', AppColors.blue, AppIcons.trips),
                  Container(width: 1, height: 40, color: AppColors.border),
                  _buildStat('4.9', 'Đánh giá', AppColors.orange, AppIcons.star),
                  Container(width: 1, height: 40, color: AppColors.border),
                  _buildStat('2', 'Năm gắn bó', AppColors.green, AppIcons.shield),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick actions
            if (auth.isAdmin)
              _buildAction(
                Icons.admin_panel_settings_rounded,
                'Bảng điều khiển Admin',
                'Quản trị hệ thống',
                AppColors.blue,
                () => Navigator.pushNamed(context, '/admin'),
              ),
            _buildAction(AppIcons.verified, 'Xác minh tài khoản', 'Đã xác minh', AppColors.green),
            _buildAction(AppIcons.shield, 'Đổi mật khẩu', '', AppColors.blue),
            _buildAction(AppIcons.delete, 'Xóa tài khoản', '', AppColors.red, () => _confirmDeleteAccount(context)),

            if (_editing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _editing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(AppIcons.verified, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Đã cập nhật thông tin thành công'),
                          ],
                        ),
                        backgroundColor: AppColors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  child: Text('Lưu thay đổi', style: AppTextStyles.button),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool editable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            enabled: editable,
            style: AppTextStyles.body1.copyWith(color: AppColors.text),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.text3, size: 20),
              filled: true,
              fillColor: editable ? AppColors.bg2 : AppColors.bg3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value, style: AppTextStyles.heading3.copyWith(color: AppColors.text)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildAction(IconData icon, String title, String subtitle, Color color, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            IconContainer(
              icon: icon,
              color: color,
              size: 36,
              iconSize: 18,
              borderRadius: AppRadius.sm,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600))),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(AppIcons.forward, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 24),
            const SizedBox(width: 8),
            Text('Xác nhận xóa tài khoản', style: AppTextStyles.heading3.copyWith(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn xóa tài khoản này không? Hành động này sẽ:',
              style: AppTextStyles.body2.copyWith(color: AppColors.text, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text('• Hủy toàn bộ phiên đăng nhập trên mọi thiết bị.', style: AppTextStyles.caption),
            Text('• Ẩn toàn bộ thông tin cá nhân (PII) theo Nghị định 13/2023/NĐ-CP.', style: AppTextStyles.caption),
            Text('• Giải phóng số điện thoại để có thể đăng ký tài khoản mới khi cần.', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Text('• Bạn sẽ không thể hoàn tác sau khi đã xóa.', style: AppTextStyles.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy bỏ', style: AppTextStyles.body2.copyWith(color: AppColors.text3, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.red)),
      );

      final auth = context.read<AuthProvider>();
      final success = await auth.deleteAccount();

      if (context.mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa tài khoản thành công. Hẹn gặp lại bạn!'),
              backgroundColor: AppColors.green,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.error ?? 'Không thể xóa tài khoản. Vui lòng thử lại.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }
}
