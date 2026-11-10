import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // Tải lịch sử thật từ trip-service (qua gateway) khi vào màn hình
    Future.microtask(
        () => context.read<TripProvider>().loadTrips(refresh: true));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final allTrips = tripProvider.trips;
    final rideTrips = tripProvider.tripsByService({'ride', 'designated_driver'});
    final foodTrips =
        tripProvider.tripsByService({'food_delivery', 'grocery'});

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
      body: _buildBody(tripProvider, allTrips, rideTrips, foodTrips),
    );
  }

  Widget _buildBody(
    TripProvider provider,
    List<TripModel> allTrips,
    List<TripModel> rideTrips,
    List<TripModel> foodTrips,
  ) {
    if (provider.state == TripLoadState.loading && !provider.hasData) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }

    if (provider.state == TripLoadState.error && !provider.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(provider.errorMessage ?? 'Có lỗi xảy ra',
                style: const TextStyle(color: AppColors.text3, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: () => provider.refresh(),
      child: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildTripList(allTrips),
          _buildTripList(rideTrips),
          _buildFoodList(foodTrips),
        ],
      ),
    );
  }

  Widget _buildTripList(List<TripModel> trips) {
    if (trips.isEmpty) {
      return ListView( // bọc trong ListView để RefreshIndicator hoạt động
        children: const [
          SizedBox(height: 120),
          Center(child: Column(children: [
            Text('📋', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Chưa có chuyến nào', style: TextStyle(color: AppColors.text3, fontSize: 15)),
          ])),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildTripCard(trips[i]),
    );
  }

  Widget _buildFoodList(List<TripModel> trips) {
    if (trips.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Column(children: [
            Text('🍔', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Chưa có đơn đồ ăn nào', style: TextStyle(color: AppColors.text3, fontSize: 15)),
          ])),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildFoodCard(trips[i]),
    );
  }

  Widget _buildTripCard(TripModel trip) {
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

    final sType = trip.serviceType;
    final isCompleted = !trip.isCancelled;
    final time = DateFormat('HH:mm').format(trip.displayTime);
    final date = DateFormat('dd/MM').format(trip.displayTime);

    return GestureDetector(
      onTap: () {
        if (sType == 'food_delivery' || sType == 'grocery') {
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
                  '${trip.pickupAddress} → ${trip.dropoffAddress}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(children: [
                  if (trip.distanceKm != null)
                    Text(
                      '${trip.distanceKm!.toStringAsFixed(1)} km${trip.durationMin != null ? ' · ${trip.durationMin} phút' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.text3),
                    ),
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
                  if (trip.rating != null) ...[
                    const SizedBox(width: 6),
                    Text('⭐ ${trip.rating}', style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtVND(trip.displayFare),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              Text('$time · $date',
                style: const TextStyle(fontSize: 11, color: AppColors.text3)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCard(TripModel trip) {
    final isCompleted = !trip.isCancelled;
    final time = DateFormat('HH:mm').format(trip.displayTime);
    final date = DateFormat('dd/MM').format(trip.displayTime);
    final isGrocery = trip.serviceType == 'grocery';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/order-detail'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: isGrocery ? AppColors.greenBg : AppColors.orangeBg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(isGrocery ? '🛒' : '🍔', style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip.pickupAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis),
              Text('Đến: ${trip.dropoffAddress}  •  $time · $date', style: const TextStyle(fontSize: 12, color: AppColors.text3), overflow: TextOverflow.ellipsis),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtVND(trip.displayFare), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isCompleted ? AppColors.greenBg : AppColors.redBg, borderRadius: BorderRadius.circular(4)),
                child: Text(isCompleted ? 'Đã giao' : 'Đã hủy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isCompleted ? AppColors.green : AppColors.red)),
              ),
            ]),
          ]),
          if (trip.rating != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
              child: Text('⭐ ${trip.rating}${trip.comment != null && trip.comment!.isNotEmpty ? ' — "${trip.comment}"' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 2, overflow: TextOverflow.ellipsis),
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
              onTap: () => Navigator.pushNamed(context, isGrocery ? '/grocery' : '/food'),
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
}
