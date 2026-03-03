import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/booking_provider.dart';
import '../models/ride.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ========== MAP with route ==========
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (booking.pickupLat + booking.dropoffLat) / 2,
                  (booking.pickupLng + booking.dropoffLng) / 2,
                ),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                // Route line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(booking.pickupLat, booking.pickupLng),
                        LatLng(booking.dropoffLat, booking.dropoffLng),
                      ],
                      color: AppColors.cyan,
                      strokeWidth: 3,
                      isDotted: true,
                    ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(booking.pickupLat, booking.pickupLng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.greenBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.green, width: 2),
                        ),
                        child: const Center(
                            child: Text('📍', style: TextStyle(fontSize: 16))),
                      ),
                    ),
                    Marker(
                      point: LatLng(booking.dropoffLat, booking.dropoffLng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.redBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.red, width: 2),
                        ),
                        child: const Center(
                            child: Text('🏁', style: TextStyle(fontSize: 16))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () {
                  booking.reset();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_back, color: AppColors.text, size: 20),
                  ),
                ),
              ),
            ),
          ),

          // ========== Bottom Panel ==========
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.text3.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Route summary
                  _buildRoute(booking),
                  const SizedBox(height: 16),

                  // Vehicle selection
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Chọn loại xe',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: VehicleType.values.map((v) {
                      final isSelected = booking.vehicleType == v;
                      final fare = booking.fareEstimates[v];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => booking.selectVehicle(v),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.blueBg
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.blue
                                    : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(v.icon,
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(height: 4),
                                Text(v.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.blue
                                          : AppColors.text2,
                                    )),
                                if (fare != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtVND(fare),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppColors.green
                                          : AppColors.text,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Payment
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Text('💵', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _paymentName(booking.paymentMethod),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.text3, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Book button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: booking.state == BookingState.searching
                          ? null
                          : () {
                              booking.bookRide();
                              Navigator.pushNamed(context, '/tracking');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        booking.state == BookingState.searching
                            ? 'Đang tìm tài xế...'
                            : '🚗 Đặt xe ngay',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoute(BookingProvider booking) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.pickupAddress.isEmpty
                      ? 'Vị trí hiện tại'
                      : booking.pickupAddress,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              children: List.generate(
                3, (_) => Container(
                  width: 2, height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  color: AppColors.border,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.dropoffAddress,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _paymentName(String method) {
    switch (method) {
      case 'momo': return 'MoMo';
      case 'zalopay': return 'ZaloPay';
      case 'vnpay': return 'VNPay';
      default: return 'Tiền mặt';
    }
  }
}
