import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rng = Random(42);
    final allTrips = _generateTrips(rng);
    final rideTrips = allTrips.where((t) => t['service_type'] == 'ride' || t['service_type'] == 'designated_driver').toList();
    final foodTrips = allTrips.where((t) => t['service_type'] == 'food_delivery').toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Lịch sử', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.blue,
          indicatorWeight: 3,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.text3,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: '🚗 Xe'),
            Tab(text: '🍔 Đồ ăn'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildTripList(allTrips),
          _buildTripList(rideTrips),
          _buildFoodList(foodTrips),
        ],
      ),
    );
  }

  Widget _buildTripList(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('📋', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('Chưa có chuyến nào', style: TextStyle(color: AppColors.text3, fontSize: 15)),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildTripCard(trips[i]),
    );
  }

  Widget _buildFoodList(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🍔', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('Chưa có đơn đồ ăn nào', style: TextStyle(color: AppColors.text3, fontSize: 15)),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildFoodCard(trips[i]),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final typeColors = {
      'ride': AppColors.blueBg,
      'food_delivery': AppColors.orangeBg,
      'grocery': AppColors.greenBg,
      'designated_driver': AppColors.purpleBg,
    };
    final typeIcons = {
      'ride': '🚗',
      'food_delivery': '🍔',
      'grocery': '🛒',
      'designated_driver': '🚙',
    };

    final sType = trip['service_type'] as String;
    final isCompleted = trip['status'] == 'completed';

    return GestureDetector(
      onTap: () {
        if (sType == 'food_delivery') {
          Navigator.pushNamed(context, '/order-detail');
        } else {
          Navigator.pushNamed(context, '/ride-detail');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: typeColors[sType] ?? AppColors.blueBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: Text(typeIcons[sType] ?? '🚗', style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  sType == 'food_delivery'
                    ? trip['restaurant'] as String
                    : '${trip['pickup']} → ${trip['dropoff']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(children: [
                  if (sType == 'food_delivery')
                    Text('${trip['items']} món', style: const TextStyle(fontSize: 12, color: AppColors.text3))
                  else
                    Text('${(trip['distance_km'] as double).toStringAsFixed(1)} km · ${trip['duration_min']} phút',
                      style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.greenBg : AppColors.redBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCompleted ? 'Hoàn thành' : 'Đã hủy',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isCompleted ? AppColors.green : AppColors.red),
                    ),
                  ),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtVND(trip['fare'] as double),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              Text('${trip['time']} · ${trip['date']}',
                style: const TextStyle(fontSize: 11, color: AppColors.text3)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> trip) {
    final isCompleted = trip['status'] == 'completed';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/order-detail'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(trip['emoji'] as String, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip['restaurant'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              Text('${trip['items']} món  •  ${trip['time']} · ${trip['date']}', style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtVND(trip['fare'] as double), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isCompleted ? AppColors.greenBg : AppColors.redBg, borderRadius: BorderRadius.circular(4)),
                child: Text(isCompleted ? 'Đã giao' : 'Đã hủy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isCompleted ? AppColors.green : AppColors.red)),
              ),
            ]),
          ]),
          // Menu items preview
          if (trip['menuItems'] != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
              child: Text(trip['menuItems'] as String, style: TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/share-bill'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('🧾 Chia bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.purple))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/food'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('🔄 Đặt lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  List<Map<String, dynamic>> _generateTrips(Random rng) {
    final serviceTypes = ['ride', 'food_delivery', 'grocery', 'designated_driver'];
    final pickups = ['Landmark 81', 'Bến Thành', 'Bitexco', 'Phú Mỹ Hưng', 'Nguyễn Huệ'];
    final dropoffs = ['TSN Airport', 'Q.7', 'Saigon Center', 'Thủ Đức', 'Gò Vấp'];
    final restaurants = ['Phở Thìn Bờ Hồ', 'Bánh Mì Huỳnh Hoa', 'Pizza 4P\'s', 'Highlands Coffee', 'Phúc Long'];
    final emojis = ['🍜', '🥖', '🍕', '☕', '🧋'];
    final menuPreviews = [
      '2x Phở tái nạm, 1x Nước chanh',
      '1x Đặc biệt, 1x Thịt nguội',
      '1x Margherita, 1x Carbonara',
      '2x Cà phê sữa đá',
      '1x Trà đào, 1x Matcha',
    ];

    return List.generate(15, (i) {
      final sType = serviceTypes[rng.nextInt(serviceTypes.length)];
      final now = DateTime.now().subtract(Duration(hours: rng.nextInt(120)));
      final rIdx = rng.nextInt(restaurants.length);
      return {
        'service_type': sType,
        'status': rng.nextDouble() < 0.85 ? 'completed' : 'cancelled',
        'pickup': pickups[rng.nextInt(pickups.length)],
        'dropoff': dropoffs[rng.nextInt(dropoffs.length)],
        'restaurant': restaurants[rIdx],
        'emoji': emojis[rIdx],
        'items': 2 + rng.nextInt(4),
        'menuItems': menuPreviews[rIdx],
        'fare': 25000 + rng.nextDouble() * 300000,
        'distance_km': 1.5 + rng.nextDouble() * 18,
        'duration_min': 8 + rng.nextInt(45),
        'time': DateFormat('HH:mm').format(now),
        'date': DateFormat('dd/MM').format(now),
      };
    });
  }
}
