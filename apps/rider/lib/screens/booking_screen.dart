import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../config/app_icons.dart';
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
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: AppColors.blue.withValues(alpha: 0.35),
                      strokeWidth: 8,
                    ),
                    Polyline(
                      points: routePoints,
                      color: AppColors.cyan,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(booking.pickupLat, booking.pickupLng),
                      width: 52,
                      height: 52,
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
                              boxShadow: AppShadows.glow(AppColors.cyan),
                            ),
                            child: Transform.rotate(
                              angle: (initialBearing - 90) * pi / 180,
                              child: const Center(
                                child: Icon(AppIcons.car, size: 22, color: AppColors.cyan),
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
                    if (booking.dropoffLat != 0)
                      Marker(
                        point: LatLng(booking.dropoffLat, booking.dropoffLng),
                        width: 46,
                        height: 46,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.redBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.red, width: 2.5),
                            boxShadow: AppShadows.glow(AppColors.red),
                          ),
                          child: const Center(
                            child: Icon(AppIcons.dropoff, color: AppColors.red, size: 22),
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
                color: AppColors.bg2.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.medium,
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.route, size: 18, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.loadingRoute
                          ? 'Đang tính toán lộ trình đường bộ...'
                          : '${booking.distanceKm > 0 ? booking.distanceKm.toStringAsFixed(1) : "13.3"} km • ~${booking.durationMin > 0 ? booking.durationMin : "19"} phút (Đường bộ)',
                      style: AppTextStyles.body2.copyWith(
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.subtle,
                  ),
                  child: const Center(
                    child: Icon(AppIcons.back, color: AppColors.text, size: 20),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.strong,
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.text3.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Route summary
                  _buildRoute(booking),
                  const SizedBox(height: 14),

                  // Vehicle selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chọn loại xe di chuyển',
                      style: AppTextStyles.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: VehicleType.values.map((v) {
                      final isSelected = booking.vehicleType == v;
                      final fare = booking.fareEstimates[v];
                      final icon = v == VehicleType.bike ? AppIcons.bike : AppIcons.car;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => booking.selectVehicle(v),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.blueBg : AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: isSelected ? AppColors.blue : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected ? AppShadows.glow(AppColors.blue) : null,
                            ),
                            child: Column(
                              children: [
                                Icon(icon, size: 26, color: isSelected ? AppColors.blue : AppColors.text2),
                                const SizedBox(height: 6),
                                Text(
                                  v.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.blue : AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fare != null ? _fmtVND(fare) : '...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppColors.green : AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Payment method
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.cash, size: 16, color: AppColors.green),
                            const SizedBox(width: 6),
                            Text('Tiền mặt', style: AppTextStyles.body2.copyWith(color: AppColors.text)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (booking.fareEstimates[booking.vehicleType] != null)
                        Text(
                          _fmtVND(booking.fareEstimates[booking.vehicleType]!),
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.green,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Book button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: booking.state == BookingState.estimating
                          ? null
                          : () async {
                              await booking.bookRide();
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(context, '/tracking');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        elevation: 4,
                        shadowColor: AppColors.blue.withValues(alpha: 0.4),
                      ),
                      child: booking.state == BookingState.estimating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'ĐẶT XE NGAY',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(AppIcons.pickup, color: AppColors.green, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.pickupAddress.isEmpty ? 'Thị xã Buôn Hồ, Đắk Lắk' : booking.pickupAddress,
                  style: AppTextStyles.body2.copyWith(color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Column(
              children: List.generate(
                2,
                (_) => Container(
                  width: 2,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: AppColors.border,
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(AppIcons.dropoff, color: AppColors.red, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.dropoffAddress.isEmpty ? 'Chọn điểm đến' : booking.dropoffAddress,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: booking.dropoffAddress.isEmpty ? AppColors.text3 : AppColors.text,
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
