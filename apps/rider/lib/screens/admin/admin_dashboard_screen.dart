import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/admin_provider.dart';
import 'admin_driver_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final admin = context.read<AdminProvider>();
      admin.refreshAll();
    });
  }

  String _formatVND(dynamic amount) {
    if (amount == null) return '0 đ';
    final n = (amount is num) ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0;
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)} tỷ';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)} tr';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(0)}k đ';
    return '${n.toStringAsFixed(0)} đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.blue, AppColors.purple]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            const Text('Quản Trị Hệ Thống', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.text),
            onPressed: () {
              context.read<AdminProvider>().refreshAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang làm mới dữ liệu quản trị...'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildOverviewTab(),
          const AdminDriverListScreen(),
          _buildLiveOrdersTab(),
          _buildFleetMapTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            final admin = context.read<AdminProvider>();
            if (index == 0) admin.loadStats();
            if (index == 1) admin.loadDrivers();
            if (index == 2) admin.loadRecentOrders();
            if (index == 3) admin.loadFleetDrivers();
          },
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.blue,
          unselectedItemColor: AppColors.text2,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Thống kê',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_user_outlined),
              activeIcon: Icon(Icons.verified_user),
              label: 'Duyệt KYC',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Cuốc xe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Bản đồ xe',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: THỐNG KÊ (OVERVIEW)
  // ==========================================
  Widget _buildOverviewTab() {
    final admin = context.watch<AdminProvider>();
    final stats = admin.stats;

    if (admin.isLoadingStats && stats == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }

    final overview = stats?['overview'] as Map<String, dynamic>? ?? {};
    final byService = stats?['by_service'] as Map<String, dynamic>? ?? {};
    final peakHours = (stats?['peak_hours'] as List? ?? []).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: () => admin.loadStats(),
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Grid
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Đơn hàng hôm nay',
                  value: '${overview['total_orders_today'] ?? 0}',
                  sub: '${overview['active_orders'] ?? 0} đang chạy',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Doanh thu hôm nay',
                  value: _formatVND(overview['total_revenue_today']),
                  sub: 'TB ${_formatVND(overview['average_order_value'])}/đơn',
                  icon: Icons.monetization_on_outlined,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Tài xế online',
                  value: '${overview['total_drivers_online'] ?? 0}',
                  sub: '${overview['total_drivers_active'] ?? 0} đang có cuốc',
                  icon: Icons.two_wheeler_outlined,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Khách hàng',
                  value: '${overview['total_customers'] ?? 0}',
                  sub: '${overview['total_merchants'] ?? 0} đối tác quán',
                  icon: Icons.people_outline,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text('PHÂN LOẠI DỊCH VỤ HÔM NAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text2, letterSpacing: 0.8)),
          const SizedBox(height: 12),

          // Services Breakdown
          _buildServiceRow('🚗 Chở khách (Ride)', byService['ride'], AppColors.blue),
          const SizedBox(height: 10),
          _buildServiceRow('🍔 Đồ ăn (Food Delivery)', byService['food_delivery'], AppColors.orange),
          const SizedBox(height: 10),
          _buildServiceRow('🛒 Đi chợ (Grocery)', byService['grocery'], AppColors.green),
          const SizedBox(height: 10),
          _buildServiceRow('🚙 Lái xe hộ (Designated)', byService['designated_driver'], AppColors.purple),

          if (peakHours.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('KHUNG GIỜ CAO ĐIỂM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text2, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: peakHours.map((p) {
                  final orders = (p['orders'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('${p['hour']}', style: const TextStyle(fontSize: 13, color: AppColors.text)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (orders / 100.0).clamp(0.05, 1.0),
                              backgroundColor: AppColors.bg3,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('$orders đơn', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard({required String title, required String value, required String sub, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildServiceRow(String name, dynamic data, Color accentColor) {
    final d = data as Map<String, dynamic>? ?? {};
    final orders = d['orders_today'] ?? 0;
    final revenue = d['revenue_today'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 36, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('$orders đơn hàng hoàn thành', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
              ],
            ),
          ),
          Text(_formatVND(revenue), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: CUỐC XE & ĐƠN HÀNG (LIVE ORDERS)
  // ==========================================
  Widget _buildLiveOrdersTab() {
    final admin = context.watch<AdminProvider>();
    final orders = admin.recentOrders;

    if (admin.isLoadingOrders && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => admin.loadRecentOrders(),
        color: AppColors.blue,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppColors.text3),
                  SizedBox(height: 12),
                  Text('Chưa có đơn hàng nào trong hệ thống', style: TextStyle(color: AppColors.text2)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => admin.loadRecentOrders(),
      color: AppColors.blue,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final o = orders[i];
          final type = o['service_type']?.toString() ?? 'ride';
          final status = o['status']?.toString() ?? 'pending';

          Color statusColor = AppColors.blue;
          String statusText = 'Đang chờ';
          if (status.contains('completed')) {
            statusColor = AppColors.green;
            statusText = 'Hoàn thành';
          } else if (status.contains('assigned') || status.contains('progress')) {
            statusColor = AppColors.orange;
            statusText = 'Đang chạy';
          } else if (status.contains('cancel')) {
            statusColor = AppColors.red;
            statusText = 'Đã hủy';
          }

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          type == 'ride' ? '🚗 Chở khách' : type == 'food_delivery' ? '🍔 Đồ ăn' : type == 'grocery' ? '🛒 Đi chợ' : '🚙 Lái xe hộ',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                    Text(_formatVND(o['fare']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.green)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.text2),
                    const SizedBox(width: 4),
                    Text('${o['customer_name'] ?? 'Khách vãng lai'}', style: const TextStyle(fontSize: 12, color: AppColors.text)),
                    const Spacer(),
                    Text('${o['created_at'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 14, color: AppColors.blue),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${o['pickup'] ?? 'Điểm đón'}', style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: AppColors.red),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${o['dropoff'] ?? 'Điểm đến'}', style: const TextStyle(fontSize: 12, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 4: BẢN ĐỒ ĐỘI XE (FLEET MAP)
  // ==========================================
  Widget _buildFleetMapTab() {
    final admin = context.watch<AdminProvider>();
    final fleet = admin.fleetDrivers;

    LatLng initialCenter = const LatLng(12.8055, 108.2612);
    if (fleet.isNotEmpty) {
      final first = fleet.first;
      final lat = (first['lat'] as num?)?.toDouble() ?? 12.8055;
      final lng = (first['lng'] as num?)?.toDouble() ?? 108.2612;
      initialCenter = LatLng(lat, lng);
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 13.5,
          ),
          children: [
            TileLayer(
              urlTemplate: ApiConfig.mapTileUrl,
              fallbackUrl: ApiConfig.mapTileFallbackUrl,
              userAgentPackageName: 'com.xebuonho.admin',
            ),
            TileLayer(
              urlTemplate: ApiConfig.mapTileLabelsUrl,
              userAgentPackageName: 'com.xebuonho.admin',
            ),
            MarkerLayer(
              markers: fleet.map((d) {
                final lat = (d['lat'] as num?)?.toDouble() ?? 12.8055;
                final lng = (d['lng'] as num?)?.toDouble() ?? 108.2612;
                final status = d['status']?.toString() ?? 'online';
                final isAvailable = status == 'online' || status == 'idle';
                final color = isAvailable ? AppColors.green : AppColors.orange;

                return Marker(
                  point: LatLng(lat, lng),
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2.5),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2),
                      ],
                    ),
                    child: Icon(
                      Icons.two_wheeler,
                      color: color,
                      size: 22,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Floating Info Banner
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Đang trực tuyến: ${fleet.length} tài xế',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                const Spacer(),
                const Text('Cập nhật realtime', style: TextStyle(fontSize: 11, color: AppColors.text2)),
              ],
            ),
          ),
        ),

        // Reload Button
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.small(
            backgroundColor: AppColors.blue,
            child: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () {
              admin.loadFleetDrivers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang quét vị trí tài xế gần nhất...'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ),
      ],
    );
  }
}
