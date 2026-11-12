import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _locationAlways = false;
  bool _darkMode = true;
  bool _biometric = false;
  String _language = 'vi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('THÔNG BÁO', [
              _buildToggle(Icons.notifications_outlined, 'Push notifications', 'Nhận thông báo đẩy', _notifications, (v) => setState(() => _notifications = v)),
            ]),

            _buildSection('QUYỀN RIÊNG TƯ', [
              _buildToggle(Icons.location_on_outlined, 'Vị trí luôn bật', 'Cho phép truy cập GPS liên tục', _locationAlways, (v) => setState(() => _locationAlways = v)),
              _buildToggle(Icons.fingerprint, 'Sinh trắc học', 'Đăng nhập bằng vân tay / Face ID', _biometric, (v) => setState(() => _biometric = v)),
            ]),

            _buildSection('GIAO DIỆN', [
              _buildToggle(Icons.dark_mode_outlined, 'Chế độ tối', 'Giao diện tối cho mắt', _darkMode, (v) => setState(() => _darkMode = v)),
              _buildSelect(Icons.language, 'Ngôn ngữ', _language == 'vi' ? 'Tiếng Việt' : 'English', () {
                setState(() => _language = _language == 'vi' ? 'en' : 'vi');
              }),
            ]),

            _buildSection('ỨNG DỤNG', [
              _buildInfo(Icons.info_outline, 'Phiên bản', 'v1.0.0 (build 1)'),
              _buildInfo(Icons.storage_outlined, 'Bộ nhớ cache', '12.3 MB'),
              _buildAction(Icons.delete_sweep_outlined, 'Xóa cache', AppColors.orange, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Đã xóa cache'), backgroundColor: AppColors.green),
                );
              }),
            ]),

            _buildSection('PHÁP LÝ', [
              _buildLink(Icons.description_outlined, 'Điều khoản sử dụng'),
              _buildLink(Icons.privacy_tip_outlined, 'Chính sách bảo mật'),
              _buildLink(Icons.gavel, 'Giấy phép nguồn mở'),
            ]),

            const SizedBox(height: 24),

            // Logout
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton(
                onPressed: () {
                  context.read<AuthProvider>().logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('🚪 Đăng xuất', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton(
                onPressed: () => _confirmDeleteAccount(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('🗑️ Xóa tài khoản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red.withValues(alpha: 0.85))),
              ),
            ),
            const SizedBox(height: 20),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.text3, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.green,
            inactiveThumbColor: AppColors.text3,
            inactiveTrackColor: AppColors.bg3,
          ),
        ],
      ),
    );
  }

  Widget _buildSelect(IconData icon, String title, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.text3, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
            Text(value, style: const TextStyle(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.text3, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.text3, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
          Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text3)),
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color))),
            Icon(Icons.chevron_right, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLink(IconData icon, String title) {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.text3, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
            const Icon(Icons.open_in_new, color: AppColors.text3, size: 14),
          ],
        ),
      ),
    );
  }
}
