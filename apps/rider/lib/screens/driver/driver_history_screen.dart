import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/driver_provider.dart';
import '../../models/driver_models.dart';

class DriverHistoryScreen extends StatelessWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final trips = driver.completedTrips;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: const Text('Lịch sử cuốc xe đối tác', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: trips.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.text3),
                  ),
                  const SizedBox(height: 16),
                  const Text('Chưa có cuốc xe nào hoàn thành', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  const SizedBox(height: 6),
                  const Text('Bật trực tuyến và nhận cuốc xe để xem lịch sử', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = trips[index];
                final req = trip.request;
                final isCompleted = trip.status == DriverTripStatus.completed;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted ? AppColors.greenBg : AppColors.redBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCompleted ? '✓ Hoàn thành' : '✕ Đã hủy',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isCompleted ? AppColors.green : AppColors.red,
                              ),
                            ),
                          ),
                          Text(
                            isCompleted ? '+${_formatCurrency(req.driverEarning)}đ' : '0đ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isCompleted ? AppColors.green : AppColors.text3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Khách: ${req.riderName} • ${req.distanceKm} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 6),
                      Text('Đón: ${req.pickupAddress}', style: const TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Trả: ${req.dropoffAddress}', style: const TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
