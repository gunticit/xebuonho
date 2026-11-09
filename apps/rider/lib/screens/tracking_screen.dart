import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../providers/booking_provider.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import 'package:intl/intl.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _animTimer;
  StreamSubscription<Position>? _gpsSubscription;

  // Real vs Simulation Mode
  bool _isRealGpsMode = false;

  // Vehicle position & heading
  double _vehicleLat = 0;
  double _vehicleLng = 0;
  double _vehicleBearing = 0;
  double _currentSpeedKmH = 0;

  // Turn-by-turn road animation state
  int _currentRouteIndex = 0;
  List<LatLng> _fullRoute = [];

  // Trip stats
  int _etaMin = 15;
  double _remainingKm = 0;
  final String _driverName = 'Nguyễn Văn Hùng';
  final String _driverPlate = '47A-123.45';
  final double _driverRating = 4.95;

  final _statusSteps = [
    {'key': 'assigned', 'label': 'Đã nhận cuốc', 'icon': '✅'},
    {'key': 'arriving', 'label': 'Tài xế đang đến', 'icon': '🚗'},
    {'key': 'arrived', 'label': 'Đã đến điểm đón', 'icon': '📍'},
    {'key': 'moving', 'label': 'Đang di chuyển', 'icon': '🏁'},
  ];
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTracking();
    });
  }

  void _initTracking() {
    final booking = context.read<BookingProvider>();

    // Load route points if already computed, or compute fallback
    if (booking.routePoints.isNotEmpty) {
      _fullRoute = List.from(booking.routePoints);
    } else {
      _fullRoute = [
        LatLng(booking.pickupLat, booking.pickupLng),
        LatLng(
          booking.dropoffLat != 0 ? booking.dropoffLat : booking.pickupLat + 0.02,
          booking.dropoffLng != 0 ? booking.dropoffLng : booking.pickupLng + 0.02,
        ),
      ];
    }

    _vehicleLat = _fullRoute.first.latitude;
    _vehicleLng = _fullRoute.first.longitude;
    _remainingKm = booking.distanceKm > 0 ? booking.distanceKm : 13.3;
    _etaMin = booking.durationMin > 0 ? booking.durationMin : 19;

    if (_fullRoute.length >= 2) {
      _vehicleBearing = RoutingService.calculateBearing(_fullRoute[0], _fullRoute[1]);
    }

    _startRoadSimulation();
  }

  void _startRoadSimulation() {
    _gpsSubscription?.cancel();
    _animTimer?.cancel();
    _isRealGpsMode = false;

    // Advance vehicle along the road network waypoints smoothly
    _animTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted || _fullRoute.isEmpty) return;

      setState(() {
        if (_currentRouteIndex < _fullRoute.length - 1) {
          final pA = _fullRoute[_currentRouteIndex];
          final pB = _fullRoute[_currentRouteIndex + 1];

          _vehicleBearing = RoutingService.calculateBearing(pA, pB);
          _vehicleLat = pB.latitude;
          _vehicleLng = pB.longitude;
          _currentSpeedKmH = 32.0 + Random().nextDouble() * 8.0;

          _currentRouteIndex++;
          final progress = _currentRouteIndex / _fullRoute.length;
          final totalKm = context.read<BookingProvider>().distanceKm > 0
              ? context.read<BookingProvider>().distanceKm
              : 13.3;
          _remainingKm = max(0.1, totalKm * (1.0 - progress));
          _etaMin = max(1, (_remainingKm / 0.5).round());

          if (progress > 0.1 && progress < 0.9) {
            _currentStep = 3; // Moving
          } else if (progress >= 0.95) {
            _etaMin = 0;
            _remainingKm = 0;
            _currentSpeedKmH = 0;
          }
        }
      });
    });
  }

  void _startRealDeviceGps() {
    _animTimer?.cancel();
    _isRealGpsMode = true;

    try {
      _gpsSubscription = LocationService.getLocationStream().listen(
        (Position pos) {
          if (!mounted) return;
          setState(() {
            final oldPos = LatLng(_vehicleLat, _vehicleLng);
            final newPos = LatLng(pos.latitude, pos.longitude);

            if (_vehicleLat != 0 && (oldPos.latitude != newPos.latitude || oldPos.longitude != newPos.longitude)) {
              _vehicleBearing = RoutingService.calculateBearing(oldPos, newPos);
            }

            _vehicleLat = pos.latitude;
            _vehicleLng = pos.longitude;
            _currentSpeedKmH = pos.speed * 3.6; // m/s to km/h

            // Center camera on real vehicle
            _mapController.move(newPos, 16);
          });
        },
        onError: (e) {
          debugPrint('GPS stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not start GPS stream: $e');
    }
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _gpsSubscription?.cancel();
    super.dispose();
  }

  String _fmtVND(double amount) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    return '${fmt.format(amount)}đ';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();

    // Route points sliced into remaining ahead road
    List<LatLng> remainingRoute = [];
    if (_fullRoute.isNotEmpty) {
      if (_currentRouteIndex < _fullRoute.length) {
        remainingRoute = _fullRoute.sublist(_currentRouteIndex);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ========== MAP with real-time tracking ==========
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                _vehicleLat != 0 ? _vehicleLat : booking.pickupLat,
                _vehicleLng != 0 ? _vehicleLng : booking.pickupLng,
              ),
              initialZoom: 14.5,
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
              // Full background road line
              if (_fullRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _fullRoute,
                      color: Colors.white.withOpacity(0.18),
                      strokeWidth: 5,
                    ),
                  ],
                ),
              // Active remaining road ahead (Glowing Cyan)
              if (remainingRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: remainingRoute,
                      color: AppColors.cyan.withOpacity(0.35),
                      strokeWidth: 8,
                    ),
                    Polyline(
                      points: remainingRoute,
                      color: AppColors.cyan,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Pickup Pin
                  Marker(
                    point: LatLng(booking.pickupLat, booking.pickupLng),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.green, width: 2),
                      ),
                      child: const Center(
                        child: Text('📍', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  // Dropoff Pin (Ea Siên / Destination)
                  if (booking.dropoffLat != 0)
                    Marker(
                      point: LatLng(booking.dropoffLat, booking.dropoffLng),
                      width: 42,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.redBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.red, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🏁', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  // Moving Vehicle Marker with Road Heading Rotation
                  Marker(
                    point: LatLng(_vehicleLat, _vehicleLng),
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing outer radar circle
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cyan.withOpacity(0.2),
                            border: Border.all(color: AppColors.cyan.withOpacity(0.6), width: 1.5),
                          ),
                        ),
                        // Vehicle icon rotated in the direction of the road
                        Transform.rotate(
                          angle: (_vehicleBearing - 90) * pi / 180,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cyan, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('🚗', style: TextStyle(fontSize: 20)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ========== TOP CONTROLS & STATUS ==========
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () {
                          booking.reset();
                          Navigator.pushReplacementNamed(context, '/home');
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
                      const SizedBox(width: 10),

                      // Mode Switcher Toggle: Real GPS vs Road Simulation
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_isRealGpsMode) {
                              _startRoadSimulation();
                            } else {
                              _startRealDeviceGps();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: _isRealGpsMode ? AppColors.greenBg : AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isRealGpsMode ? AppColors.green : AppColors.border,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isRealGpsMode ? '🛰️' : '🚗', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  _isRealGpsMode ? 'GPS Thực tế (Đang bật)' : 'Chế độ mô phỏng xe chạy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _isRealGpsMode ? AppColors.green : AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Real-time speed & distance floating pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bg2.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentSpeedKmH.toStringAsFixed(0)} km/h',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text('📏', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Còn ${_remainingKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text('⏱️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '$_etaMin phút',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

          // Re-center Floating Button
          Positioned(
            right: 16,
            bottom: 270,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(_vehicleLat, _vehicleLng), 16);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎯', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),

          // ========== BOTTOM DRIVER PANEL ==========
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
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
                  const SizedBox(height: 12),

                  // Progress Step Bar
                  Row(
                    children: _statusSteps.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final isDone = i <= _currentStep;
                      final isCurrent = i == _currentStep;

                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.blueBg
                                    : isDone
                                        ? AppColors.greenBg
                                        : AppColors.card,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrent
                                      ? AppColors.blue
                                      : isDone
                                          ? AppColors.green
                                          : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(s['icon']!, style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s['label']!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent
                                    ? AppColors.blue
                                    : isDone
                                        ? AppColors.text
                                        : AppColors.text3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Driver profile card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.blueBg,
                          child: const Text('👨🏻‍✈️', style: TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _driverName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.orangeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('⭐', style: TextStyle(fontSize: 10)),
                                        const SizedBox(width: 2),
                                        Text(
                                          _driverRating.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Toyota Vios • Biển số: $_driverPlate',
                                style: const TextStyle(fontSize: 12, color: AppColors.text3),
                              ),
                            ],
                          ),
                        ),
                        // Call button
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.greenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('📞', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Chat button
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.blueBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('💬', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Route destinations summary
                  Row(
                    children: [
                      const Text('🟢', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.pickupAddress.isNotEmpty ? booking.pickupAddress : 'Thị xã Buôn Hồ',
                          style: const TextStyle(fontSize: 11, color: AppColors.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('🏁', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.dropoffAddress.isNotEmpty ? booking.dropoffAddress : 'Xã Ea Siên',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
