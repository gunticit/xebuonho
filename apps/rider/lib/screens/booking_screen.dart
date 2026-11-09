import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../providers/booking_provider.dart';
import '../models/ride.dart';
import '../services/routing_service.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final MapController _mapController = MapController();
  bool _hasFittedRoute = false;

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      if (booking.routePoints.isEmpty && booking.dropoffLat != 0) {
        booking.fetchRoute();
      }
    });
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty || _hasFittedRoute) return;
    _hasFittedRoute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(top: 80, bottom: 40, left: 50, right: 50),
          ),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();

    // Auto-fit camera if route is ready
    if (booking.routePoints.isNotEmpty && !_hasFittedRoute) {
      _fitMapToRoute(booking.routePoints);
    }

    final routePoints = booking.routePoints.isNotEmpty
        ? booking.routePoints
        : [
            LatLng(booking.pickupLat, booking.pickupLng),
            LatLng(
              booking.dropoffLat != 0 ? booking.dropoffLat : booking.pickupLat + 0.01,
              booking.dropoffLng != 0 ? booking.dropoffLng : booking.pickupLng + 0.01,
            ),
          ];

    // Calculate initial vehicle heading
    double initialBearing = 0;
    if (routePoints.length >= 2) {
      initialBearing = RoutingService.calculateBearing(routePoints[0], routePoints[1]);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ========== MAP with real road route ==========
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.48,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  booking.dropoffLat != 0
                      ? (booking.pickupLat + booking.dropoffLat) / 2
                      : booking.pickupLat,
                  booking.dropoffLng != 0
                      ? (booking.pickupLng + booking.dropoffLng) / 2
                      : booking.pickupLng,
                ),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiConfig.mapTileUrl,
                  fallbackUrl: ApiConfig.mapTileFallbackUrl,
                  userAgentPackageName: 'com.xebuonho.rider',
                ),
                TileLayer(
                  urlTemplate: ApiConfig.mapTileLabelsUrl,
                  userAgentPackageName: 'com.xebuonho.rider',
                ),
                // Outer glow casing
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: AppColors.blue.withOpacity(0.35),
                      strokeWidth: 8,
                    ),
                    // Inner sharp solid road path
                    Polyline(
                      points: routePoints,
                      color: AppColors.cyan,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Vehicle Marker at Pickup with road orientation
                    Marker(
                      point: LatLng(booking.pickupLat, booking.pickupLng),
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.card,
                              border: Border.all(color: AppColors.cyan, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.4),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Transform.rotate(
                              angle: (initialBearing - 90) * pi / 180,
                              child: const Center(
                                child: Text('🚗', style: TextStyle(fontSize: 22)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dropoff Flag Marker
                    if (booking.dropoffLat != 0)
                      Marker(
                        point: LatLng(booking.dropoffLat, booking.dropoffLng),
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.redBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.red, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.red.withOpacity(0.35),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🏁', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Route info badge (Distance & ETA)
          Positioned(
            top: 54,
            left: 70,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg2.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🛣️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.loadingRoute
                          ? 'Đang tính toán lộ trình đường bộ...'
                          : '${booking.distanceKm > 0 ? booking.distanceKm.toStringAsFixed(1) : "13.3"} km • ~${booking.durationMin > 0 ? booking.durationMin : "19"} phút (Đường bộ)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.text3.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Route summary
                  _buildRoute(booking),
                  const SizedBox(height: 14),

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
                            padding: const EdgeInsets.symmetric(vertical: 10),
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
                                Text(v.icon, style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(v.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.blue
                                          : AppColors.text,
                                    )),
                                const SizedBox(height: 2),
                                Text(
                                  fare != null ? _fmtVND(fare) : '...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.green
                                        : AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Payment method
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('💵', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Text('Tiền mặt',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.text)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (booking.fareEstimates[booking.vehicleType] != null)
                        Text(
                          _fmtVND(booking.fareEstimates[booking.vehicleType]!),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Book button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: booking.state == BookingState.estimating
                          ? null
                          : () async {
                              await booking.confirmBooking();
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                    context, '/tracking');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: booking.state == BookingState.estimating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'ĐẶT XE NGAY',
                              style: TextStyle(
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
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.pickupAddress.isEmpty
                      ? 'Thị xã Buôn Hồ, Đắk Lắk'
                      : booking.pickupAddress,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              children: List.generate(
                2,
                (_) => Container(
                  width: 2,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  color: AppColors.border,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.dropoffAddress.isEmpty
                      ? 'Chọn điểm đến'
                      : booking.dropoffAddress,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: booking.dropoffAddress.isEmpty
                        ? AppColors.text3
                        : AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
