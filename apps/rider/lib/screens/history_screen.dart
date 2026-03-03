import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/ride.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  Widget build(BuildContext context) {
    final rng = Random(42);
    final trips = _generateTrips(rng);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text(
          'Lịch sử chuyến đi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: trips.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🚗', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Chưa có chuyến nào',
                      style: TextStyle(color: AppColors.text3, fontSize: 15)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildTripCard(trips[i]),
            ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColors[sType] ?? AppColors.blueBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(typeIcons[sType] ?? '🚗',
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip['pickup']} → ${trip['dropoff']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          '${(trip['distance_km'] as double).toStringAsFixed(1)} km · ${trip['duration_min']} phút',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.text3),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.greenBg
                                : AppColors.redBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCompleted ? 'Hoàn thành' : 'Đã hủy',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  isCompleted ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtVND(trip['fare'] as double),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '${trip['time']} · ${trip['date']}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.text3),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateTrips(Random rng) {
    final serviceTypes = ['ride', 'food_delivery', 'grocery', 'designated_driver'];
    final pickups = ['Landmark 81', 'Bến Thành', 'Bitexco', 'Phú Mỹ Hưng', 'Nguyễn Huệ'];
    final dropoffs = ['TSN Airport', 'Q.7', 'Saigon Center', 'Thủ Đức', 'Gò Vấp'];

    return List.generate(12, (i) {
      final now = DateTime.now().subtract(Duration(hours: rng.nextInt(72)));
      return {
        'service_type': serviceTypes[rng.nextInt(serviceTypes.length)],
        'status': rng.nextDouble() < 0.9 ? 'completed' : 'cancelled',
        'pickup': pickups[rng.nextInt(pickups.length)],
        'dropoff': dropoffs[rng.nextInt(dropoffs.length)],
        'fare': 25000 + rng.nextDouble() * 300000,
        'distance_km': 1.5 + rng.nextDouble() * 18,
        'duration_min': 8 + rng.nextInt(45),
        'time': DateFormat('HH:mm').format(now),
        'date': DateFormat('dd/MM').format(now),
      };
    });
  }
}
