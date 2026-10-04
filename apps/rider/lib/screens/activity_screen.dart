import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/active_order_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _selectedFilter = 'all'; // 'all', 'ride', 'food', 'grocery', 'designated', 'delivery'

  final List<Map<String, dynamic>> _mockHistory = [
    {
      'id': 'FOOD-8891',
      'type': 'food',
      'title': 'Cơm Tấm Phúc Lộc Thọ',
      'subtitle': '1x Cơm sườn bì chả, 1x Canh rong biển',
      'price': 68000,
      'status': 'Đã hoàn thành',
      'emoji': '🍱',
      'time': '12:30 Hôm nay',
      'rating': 5,
    },
    {
      'id': 'RIDE-1294',
      'type': 'ride',
      'title': 'Chuyến xe Ô tô 4 chỗ',
      'subtitle': 'Bitexco Tower ➔ Landmark 81',
      'price': 85000,
      'status': 'Đã hoàn thành',
      'emoji': '🚗',
      'time': '08:15 Hôm nay',
      'rating': 5,
    },
    {
      'id': 'DD-3341',
      'type': 'designated',
      'title': 'Lái xe hộ (Bạn say tôi lái)',
      'subtitle': 'Quán nhậu Dê Vàng ➔ Chung cư Sunwah Pearl',
      'price': 240000,
      'status': 'Đã hoàn thành',
      'emoji': '🚙',
      'time': '23:40 Hôm qua',
      'rating': 5,
    },
    {
      'id': 'GROCERY-9182',
      'type': 'grocery',
      'title': 'Đi chợ: Co.opmart Cống Quỳnh',
      'subtitle': '4 món tươi sống (Thịt, rau muống, trứng, cà chua)',
      'price': 228000,
      'status': 'Đã hoàn thành',
      'emoji': '🛒',
      'time': '16:20 25/09/2026',
      'rating': 5,
    },
    {
      'id': 'EXPRESS-4412',
      'type': 'delivery',
      'title': 'Giao hàng hỏa tốc: Hợp đồng tài liệu',
      'subtitle': 'Quận 1 ➔ Masteri Thảo Điền',
      'price': 32000,
      'status': 'Đã hoàn thành',
      'emoji': '📦',
      'time': '10:00 24/09/2026',
      'rating': 5,
    },
    {
      'id': 'RIDE-0912',
      'type': 'ride',
      'title': 'Chuyến xe Xe máy (Xebuonho Bike)',
      'subtitle': 'Sân bay Tân Sơn Nhất ➔ Chợ Bến Thành',
      'price': 42000,
      'status': 'Đã hoàn thành',
      'emoji': '🛵',
      'time': '14:10 22/09/2026',
      'rating': 5,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _fmtVND(num amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)} đ';
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = context.watch<ActiveOrderProvider>().activeOrders;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Hoạt động của bạn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.text)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.blue,
          indicatorWeight: 3,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.text3,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Đang diễn ra'),
                  if (activeOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(10)),
                      child: Text('${activeOrders.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Lịch sử đơn'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildOngoingTab(activeOrders),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOngoingTab(List<ActiveOrderEntry> activeOrders) {
    if (activeOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Không có đơn hàng nào đang chạy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text('Bạn có thể đặt xe, gọi món hoặc nhờ tài xế lái xe hộ ngay bây giờ!', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.text3)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickActionBtn('🛵 Đặt xe', '/search'),
                  _buildQuickActionBtn('🍔 Đặt đồ ăn', '/food'),
                  _buildQuickActionBtn('🚙 Lái xe hộ', '/designated-driver'),
                  _buildQuickActionBtn('🛒 Đi chợ', '/grocery'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activeOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final order = activeOrders[index];
        return _buildOngoingCard(order);
      },
    );
  }

  Widget _buildOngoingCard(ActiveOrderEntry order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.blueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(order.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(order.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
                          child: Text('~${order.etaMinutes} phút', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.orange)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(order.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.sync, size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(order.statusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.progress,
              backgroundColor: AppColors.bg3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<ActiveOrderProvider>().removeOrder(order.id);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Hủy đơn', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, order.routePath, arguments: order.routeArguments);
                  },
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Xem hành trình trực tiếp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.blue)),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final filtered = _mockHistory.where((item) {
      if (_selectedFilter == 'all') return true;
      return item['type'] == _selectedFilter;
    }).toList();

    return Column(
      children: [
        // Filter pills
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: AppColors.bg2,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả'),
                _buildFilterChip('ride', '🚗 Xe'),
                _buildFilterChip('food', '🍔 Đồ ăn'),
                _buildFilterChip('designated', '🚙 Lái xe hộ'),
                _buildFilterChip('grocery', '🛒 Đi chợ'),
                _buildFilterChip('delivery', '📦 Giao hàng'),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _buildHistoryCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : AppColors.bg3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.text2,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(item['emoji'] as String, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                    Text(item['time'] as String, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
              ),
              Text(_fmtVND(item['price'] as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['subtitle'] as String, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(6)),
                child: Text('✅ ${item['status']}', style: const TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đang tạo lại ${item['title']}...'), backgroundColor: AppColors.blue),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.blue),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Đặt lại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
