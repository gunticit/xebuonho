import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

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
        title: const Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? 'Hủy' : 'Sửa',
              style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blue, AppColors.purple],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 20)],
                    ),
                    child: Center(
                      child: Text(
                        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  if (_editing)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.green, shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenBg, borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⭐ ${auth.userRole == 'rider' ? 'Khách hàng' : auth.userRole}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
            ),
            const SizedBox(height: 28),

            // Fields
            _buildField('Họ và tên', _nameCtrl, Icons.person_outline, _editing),
            _buildField('Số điện thoại', _phoneCtrl, Icons.phone_outlined, false), // phone not editable
            _buildField('Email', _emailCtrl, Icons.email_outlined, _editing),
            const SizedBox(height: 16),

            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('27', 'Chuyến đi'),
                  Container(width: 1, height: 36, color: AppColors.border),
                  _buildStat('4.8', 'Đánh giá'),
                  Container(width: 1, height: 36, color: AppColors.border),
                  _buildStat('2', 'Năm'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick actions
            if (auth.userRole == 'admin' || auth.userRole == 'superadmin')
              _buildAction(Icons.admin_panel_settings_outlined, 'Bảng điều khiển Admin', 'Quản trị hệ thống', AppColors.blue, () => Navigator.pushNamed(context, '/admin')),
            _buildAction(Icons.verified_user, 'Xác minh tài khoản', 'Đã xác minh', AppColors.green),
            _buildAction(Icons.security, 'Đổi mật khẩu', '', AppColors.blue),
            _buildAction(Icons.delete_outline, 'Xóa tài khoản', '', AppColors.red, () => _confirmDeleteAccount(context)),

            if (_editing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _editing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Đã cập nhật'), backgroundColor: AppColors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text3)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            enabled: editable,
            style: const TextStyle(color: AppColors.text, fontSize: 15),
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

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
      ],
    );
  }

  Widget _buildAction(IconData icon, String title, String subtitle, Color color, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: const [
            Text('⚠️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Xác nhận xóa tài khoản', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Bạn có chắc chắn muốn xóa tài khoản này không? Hành động này sẽ:',
              style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text('• Hủy toàn bộ phiên đăng nhập trên mọi thiết bị.', style: TextStyle(color: AppColors.text2, fontSize: 12)),
            Text('• Ẩn toàn bộ thông tin cá nhân (PII) theo Nghị định 13/2023/NĐ-CP.', style: TextStyle(color: AppColors.text2, fontSize: 12)),
            Text('• Giải phóng số điện thoại để có thể đăng ký tài khoản mới khi cần.', style: TextStyle(color: AppColors.text2, fontSize: 12)),
            SizedBox(height: 6),
            Text('• Bạn sẽ không thể hoàn tác sau khi đã xóa.', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy bỏ', style: TextStyle(color: AppColors.text3, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        Navigator.pop(context); // Đóng loading dialog
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã xóa tài khoản thành công. Hẹn gặp lại bạn!'),
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
