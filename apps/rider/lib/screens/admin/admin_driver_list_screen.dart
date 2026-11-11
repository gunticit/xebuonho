import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/admin_provider.dart';

/// Bảng điều khiển duyệt hồ sơ tài xế (KYC moderation) — NĐ 10/2020/NĐ-CP.
class AdminDriverListScreen extends StatefulWidget {
  const AdminDriverListScreen({super.key});

  @override
  State<AdminDriverListScreen> createState() => _AdminDriverListScreenState();
}

class _AdminDriverListScreenState extends State<AdminDriverListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final admin = context.read<AdminProvider>();
    final initialIndex = _indexForStatus(admin.statusFilter);
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        admin.setFilters(status: _statusForIndex(_tabController.index));
        admin.loadDrivers();
      }
    });
    Future.microtask(() => admin.loadDrivers());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _indexForStatus(String status) {
    switch (status) {
      case 'pending_approval':
        return 0;
      case 'approved':
        return 1;
      case 'rejected':
        return 2;
      default:
        return 3; // suspended + others
    }
  }

  String _statusForIndex(int index) {
    switch (index) {
      case 0:
        return 'pending_approval';
      case 1:
        return 'approved';
      case 2:
        return 'rejected';
      default:
        return 'suspended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: const Text(
          'Quản trị — Duyệt hồ sơ tài xế',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.text3,
          indicatorColor: AppColors.blue,
          tabs: const [
            Tab(text: 'Chờ duyệt'),
            Tab(text: 'Đã duyệt'),
            Tab(text: 'Từ chối'),
            Tab(text: 'Tạm khoá'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Kind filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildKindChip(admin, '', 'Tất cả'),
                const SizedBox(width: 8),
                _buildKindChip(admin, 'personal', '🏍️ Cá nhân'),
                const SizedBox(width: 8),
                _buildKindChip(admin, 'business', '🚗 Doanh nghiệp'),
              ],
            ),
          ),
          Expanded(
            child: admin.state == AdminLoadState.loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
                : admin.state == AdminLoadState.error
                    ? _buildErrorView(admin)
                    : admin.drivers.isEmpty
                        ? const Center(
                            child: Text(
                              'Không có hồ sơ nào',
                              style: TextStyle(color: AppColors.text3, fontSize: 14),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.blue,
                            onRefresh: () => admin.loadDrivers(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: admin.drivers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _buildDriverCard(context, admin.drivers[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildKindChip(AdminProvider admin, String kind, String label) {
    final active = admin.kindFilter == kind;
    return GestureDetector(
      onTap: () {
        admin.setFilters(kind: kind);
        admin.loadDrivers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.blueBg : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.blue : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.blue : AppColors.text2,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(AdminProvider admin) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.text3, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              admin.error ?? 'Lỗi không xác định',
              style: const TextStyle(color: AppColors.text2, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => admin.loadDrivers(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
            child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, Map<String, dynamic> driver) {
    final isBusiness = driver['driver_kind'] == 'business';
    final status = driver['approval_status'] ?? '';
    final company = driver['company_name'];

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'pending_approval':
        statusColor = AppColors.orange;
        statusLabel = 'CHỜ DUYỆT';
        break;
      case 'approved':
        statusColor = AppColors.green;
        statusLabel = 'ĐÃ DUYỆT';
        break;
      case 'rejected':
        statusColor = AppColors.red;
        statusLabel = 'TỪ CHỐI';
        break;
      default:
        statusColor = AppColors.text3;
        statusLabel = 'TẠM KHOÁ';
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/admin/driver',
        arguments: driver['id'] as String,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isBusiness ? AppColors.blueBg : AppColors.orangeBg,
                  child: Text(
                    isBusiness ? '🚗' : '🏍️',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver['full_name'] ?? '—',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${driver['phone'] ?? '—'}  •  ${isBusiness ? (company ?? 'Doanh nghiệp') : 'Tài xế cá nhân'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.text2),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            if (driver['license_plate'] != null ||
                driver['rejection_reason'] != null) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (driver['license_plate'] != null) 'Biển số: ${driver['license_plate']}',
                  if (driver['rejection_reason'] != null)
                    'Lý do từ chối: ${driver['rejection_reason']}',
                ].join('  •  '),
                style: const TextStyle(fontSize: 11, color: AppColors.text3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
