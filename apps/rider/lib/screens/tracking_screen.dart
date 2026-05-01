import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/booking_provider.dart';
import 'package:intl/intl.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _driverMoveTimer;
  double _driverLat = 0;
  double _driverLng = 0;
  int _eta = 8;
  String _driverName = 'Nguyễn Văn Tài';
  String _driverPlate = '51F-123.45';
  double _driverRating = 4.9;

  final _statusSteps = [
    {'key': 'searching', 'label': 'Đang tìm', 'icon': '🔍'},
    {'key': 'assigned', 'label': 'Đã nhận', 'icon': '✅'},
    {'key': 'arriving', 'label': 'Đang đến', 'icon': '🚗'},
    {'key': 'arrived', 'label': 'Đã đến', 'icon': '📍'},
    {'key': 'moving', 'label': 'Đang đi', 'icon': '🏁'},
  ];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _simulateDriver();
  }

  void _simulateDriver() {
    final booking = context.read<BookingProvider>();
    final rng = Random();
    _driverLat = booking.pickupLat + (rng.nextDouble() - 0.5) * 0.015;
    _driverLng = booking.pickupLng + (rng.nextDouble() - 0.5) * 0.015;

    // Step 1: Searching (3s)
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _currentStep = 1);
    });

    // Step 2: Driver arriving (move towards pickup)
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _currentStep = 2);
      _driverMoveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _driverLat += (booking.pickupLat - _driverLat) * 0.15;
          _driverLng += (booking.pickupLng - _driverLng) * 0.15;
          _eta = max(1, _eta - 1);
        });
      });
    });

    // Step 3: Arrived
    Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      _driverMoveTimer?.cancel();
      setState(() {
        _currentStep = 3;
        _driverLat = booking.pickupLat;
        _driverLng = booking.pickupLng;
        _eta = 0;
      });
    });
  }

  @override
  void dispose() {
    _driverMoveTimer?.cancel();
    super.dispose();
  }

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
          // ========== MAP ==========
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(booking.pickupLat, booking.pickupLng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              // Route
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(booking.pickupLat, booking.pickupLng),
                      LatLng(booking.dropoffLat, booking.dropoffLng),
                    ],
                    color: AppColors.cyan.withOpacity(0.5),
                    strokeWidth: 3,
                    isDotted: true,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  // Driver
                  if (_currentStep >= 1)
                    Marker(
                      point: LatLng(_driverLat, _driverLng),
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.green, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withOpacity(0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🚗', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  // Pickup
                  Marker(
                    point: LatLng(booking.pickupLat, booking.pickupLng),
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.green, width: 2),
                      ),
                      child: const Center(
                        child: Text('📍', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  // Dropoff
                  Marker(
                    point: LatLng(booking.dropoffLat, booking.dropoffLng),
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.redBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.red, width: 2),
                      ),
                      child: const Center(
                        child: Text('🏁', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ========== Back button ==========
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      booking.cancelRide();
                      Navigator.popUntil(context, ModalRoute.withName('/home'));
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
                        child: Icon(Icons.close, color: AppColors.text, size: 20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // ETA badge
                  if (_eta > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Text('⏱', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            '$_eta phút',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                  // Status progress
                  _buildStatusBar(),
                  const SizedBox(height: 16),

                  // Driver info
                  if (_currentStep >= 1) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.blueBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.blue.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Text('👤', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driverName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '⭐ $_driverRating',
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.text3),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _driverPlate,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.cyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Call & chat buttons
                          _buildActionBtn('📞', AppColors.greenBg),
                          const SizedBox(width: 8),
                          _buildActionBtn('💬', AppColors.blueBg),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Ride info
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                            '📍', booking.dropoffAddress, 'Điểm đến'),
                        Container(
                            width: 1, height: 30, color: AppColors.border),
                        _buildInfoItem(
                          '💵',
                          _fmtVND(booking.fareEstimates[booking.vehicleType] ?? 0),
                          'Giá ước tính',
                        ),
                      ],
                    ),
                  ),

                  // Complete button (when arrived)
                  if (_currentStep >= 3) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          booking.completeRide();
                          Navigator.pushReplacementNamed(context, '/complete');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '✅ Tài xế đã đến — Lên xe',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Row(
      children: List.generate(_statusSteps.length, (i) {
        final step = _statusSteps[i];
        final isActive = i <= _currentStep;
        final isCurrent = i == _currentStep;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.green
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Column(
                children: [
                  Container(
                    width: isCurrent ? 32 : 26,
                    height: isCurrent ? 32 : 26,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.greenBg : AppColors.bg3,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.green
                            : isActive
                                ? AppColors.green.withOpacity(0.5)
                                : AppColors.border,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        step['icon']!,
                        style: TextStyle(fontSize: isCurrent ? 14 : 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['label']!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppColors.green : AppColors.text3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionBtn(String emoji, Color bg) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.text3),
        ),
      ],
    );
  }
}
