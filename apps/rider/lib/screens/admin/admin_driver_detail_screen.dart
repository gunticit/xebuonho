import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/admin_provider.dart';

/// Chi tiết hồ sơ tài xế: thông tin pháp lý + ảnh giấy tờ (presigned GET từ MinIO)
/// và hành động Duyệt / Từ chối / Khoá.
class AdminDriverDetailScreen extends StatefulWidget {
  const AdminDriverDetailScreen({super.key});

  @override
  State<AdminDriverDetailScreen> createState() => _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends State<AdminDriverDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;

  String _driverId = '';
  bool _resolvedArgs = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolvedArgs) {
      _driverId = ModalRoute.of(context)!.settings.arguments as String;
      _resolvedArgs = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<AdminProvider>().loadDriverDetail(_driverId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được hồ sơ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _act(String status) async {
    String reason = '';
    if (status == 'rejected') {
      final newReason = await _promptReason();
      if (newReason == null) return;
      if (newReason.trim().isEmpty) {
        _toast('Vui lòng nhập lý do từ chối');
        return;
      }
      reason = newReason;
    } else {
      final ok = await _confirm(status);
      if (!ok) return;
    }

    setState(() => _actionBusy = true);
    final admin = context.read<AdminProvider>();
    final error = await admin.setApproval(_driverId, status, reason: reason);
    if (!mounted) return;
    setState(() => _actionBusy = false);

    if (error != null) {
      _toast(error);
    } else {
      _toast(_successMessage(status));
      Navigator.pop(context, status);
    }
  }

  String _successMessage(String status) {
    switch (status) {
      case 'approved':
        return '✅ Đã phê duyệt hồ sơ. Tài xế có thể bật nhận cuốc.';
      case 'rejected':
        return 'Đã từ chối hồ sơ. Tài xế sẽ thấy lý do trên dashboard.';
      case 'suspended':
        return '🔒 Đã khoá tài khoản tài xế.';
      default:
        return 'Đã cập nhật';
    }
  }

  Future<String?> _promptReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lý do từ chối hồ sơ', style: TextStyle(color: AppColors.text, fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            hintText: 'VD: Ảnh GPLX không rõ, hết hạn bảo hiểm TNDS...',
            hintStyle: TextStyle(color: AppColors.text3, fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.text3)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String status) async {
    final label = status == 'approved'
        ? 'phê duyệt hồ sơ này'
        : 'khoá tài khoản tài xế này';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận', style: TextStyle(color: AppColors.text, fontSize: 16)),
        content: Text(
          'Bạn chắc chắn muốn $label? Hành động được ghi lại với định danh quản trị viên (audit trail).',
          style: const TextStyle(color: AppColors.text2, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: AppColors.text3)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: Text(
              status == 'approved' ? 'Duyệt' : 'Khoá',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _detail?['user'] as Map<String, dynamic>?;
    final docUrls = _detail?['doc_urls'] as Map<String, dynamic>? ?? {};
    final warnings = (_detail?['warnings'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: Text(
          user?['full_name']?.toString() ?? 'Chi tiết hồ sơ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppColors.text2)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (warnings.isNotEmpty) _buildWarnings(warnings),
                    _buildInfoCard(user),
                    const SizedBox(height: 16),
                    _buildDocsCard(docUrls),
                    const SizedBox(height: 24),
                    _buildActions(),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildWarnings(List<String> warnings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 18),
              SizedBox(width: 8),
              Text('CẢNH BÁO GIẤY TỜ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map((w) => Text(
                '• $w',
                style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.5),
              )),
        ],
      ),
    );
  }

  String? _s(dynamic v) => v?.toString();

  Widget _buildInfoCard(Map<String, dynamic>? user) {
    if (user == null) return const SizedBox.shrink();
    final isBusiness = user['driver_kind'] == 'business';
    final rows = <List<String?>>[
      ['SĐT', _s(user['phone'])],
      ['Vai trò', isBusiness ? 'Tài xế doanh nghiệp 🚗' : 'Tài xế cá nhân 🏍️'],
      ['Biển số xe', _s(user['license_plate'])],
      ['Dòng xe', _s(user['vehicle_model'])],
      ['Số CCCD', _s(user['id_card_number'])],
      ['Số GPLX (hạng)', '${_s(user['driver_license_number']) ?? '—'} (${_s(user['driver_license_class']) ?? '—'})'],
      ['Hạn GPLX', _s(user['driver_license_expiry'])],
      ['Hạn bảo hiểm TNDS', _s(user['vehicle_insurance_expiry'])],
      if (isBusiness) ...[
        ['Doanh nghiệp', _s(user['company_name'])],
        ['MST', _s(user['company_tax_code'])],
        ['Số GPKD', _s(user['business_license_number'])],
        ['Số GPLVT', _s(user['transport_license_number'])],
        ['Hạn GPLVT', _s(user['transport_license_expiry'])],
        ['Hộp đen GPS', (user['blackbox_installed'] == true) ? 'Đã lắp ✓' : 'Chưa xác nhận'],
        ['Camera cabin', (user['cabin_camera_installed'] == true) ? 'Đã lắp ✓' : 'Chưa xác nhận'],
      ],
      ['Trạng thái', _s(user['approval_status'])],
      if (user['rejection_reason'] != null) ['Lý do từ chối', _s(user['rejection_reason'])],
      ['Duyệt bởi', _s(user['approved_by'])],
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows
            .where((r) => r[1] != null)
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(r[0]!,
                            style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                      ),
                      Expanded(
                        child: Text(r[1]!,
                            style: const TextStyle(fontSize: 12, color: AppColors.text)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDocsCard(Map<String, dynamic> docUrls) {
    final labels = {
      'id_card_front': 'CCCD mặt trước',
      'id_card_back': 'CCCD mặt sau',
      'driver_license_front': 'GPLX mặt trước',
      'driver_license_back': 'GPLX mặt sau',
      'vehicle_registration': 'Đăng ký xe',
      'vehicle_insurance': 'Bảo hiểm TNDS',
      'business_license': 'GPKD doanh nghiệp',
      'transport_license': 'Giấy phép vận tải',
      'employment_contract': 'Hợp đồng lao động',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ảnh giấy tờ (hết hạn xem 15 phút)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          if (docUrls.isEmpty)
            const Text(
              'Không có ảnh giấy tờ nào được nộp.',
              style: TextStyle(fontSize: 12, color: AppColors.text3),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: docUrls.entries.map((e) {
                final label = labels[e.key] ?? e.key;
                final url = e.value.toString();
                return GestureDetector(
                  onTap: () => _viewDoc(url, label),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 104,
                          height: 74,
                          color: AppColors.bg2,
                          child: const Icon(Icons.image_outlined, color: AppColors.text3, size: 28),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 104,
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 10, color: AppColors.text2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _viewDoc(String url, String label) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Không tải được ảnh.\nURL xem trước có thể đã hết hạn — bấm nút refresh để tạo URL mới.',
                    style: TextStyle(color: AppColors.text3, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: AppColors.text2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    final status = _detail?['user']?['approval_status']?.toString() ?? '';
    return Column(
      children: [
        if (_actionBusy)
          const Center(child: CircularProgressIndicator(color: AppColors.blue))
        else ...[
          if (status != 'approved')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _act('approved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('✓ Phê duyệt hồ sơ',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          const SizedBox(height: 10),
          if (status != 'rejected')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _act('rejected'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.redBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('✕ Từ chối hồ sơ (nhập lý do)',
                    style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          const SizedBox(height: 10),
          if (status == 'approved')
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _act('suspended'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bg2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('🔒 Khoá tài khoản (vi phạm)',
                    style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
        ],
      ],
    );
  }
}
