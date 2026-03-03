import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import '../models/ride.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().fetchLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = context.watch<LocationProvider>();
    final booking = context.watch<BookingProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // ========== MAP ==========
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(locProvider.lat, locProvider.lng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.xebuonho.rider',
              ),
              // User location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(locProvider.lat, locProvider.lng),
                    width: 50,
                    height: 50,
                    child: _buildUserMarker(),
                  ),
                ],
              ),
            ],
          ),

          // ========== TOP BAR ==========
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // App header bar
                  Row(
                    children: [
                      _buildCircleBtn('☰', () {}),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🏍️',
                                style: TextStyle(fontSize: 16)),
                            SizedBox(width: 6),
                            Text(
                              'Xebuonho',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildCircleBtn('🔔', () {}),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.greenBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('📍',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Bạn muốn đi đâu?',
                              style: TextStyle(
                                color: AppColors.text3,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.blueBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('🔍',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ========== MY LOCATION BTN ==========
          Positioned(
            right: 16,
            bottom: 260,
            child: GestureDetector(
              onTap: () {
                _mapController.move(
                  LatLng(locProvider.lat, locProvider.lng),
                  16,
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎯', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),

          // ========== BOTTOM SHEET : Services ==========
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue.withOpacity(0.15),
        border: Border.all(color: AppColors.blue, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Center(
        child: Text('📍', style: TextStyle(fontSize: 20)),
      ),
    );
  }

  Widget _buildCircleBtn(String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
          const SizedBox(height: 16),

          // Quick services
          const Text(
            'Dịch vụ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceBtn(
                '🚗', 'Xe máy', AppColors.blueBg, AppColors.blue,
                () => Navigator.pushNamed(context, '/search'),
              ),
              _buildServiceBtn(
                '🚙', 'Ô tô', AppColors.greenBg, AppColors.green,
                () => Navigator.pushNamed(context, '/search'),
              ),
              _buildServiceBtn(
                '🍔', 'Đồ ăn', AppColors.orangeBg, AppColors.orange,
                () {},
              ),
              _buildServiceBtn(
                '🛒', 'Đi chợ', AppColors.purpleBg, AppColors.purple,
                () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recent places
          const Text(
            'Gần đây',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
          const SizedBox(height: 8),
          _buildRecentPlace('🏢', 'Văn phòng', 'Bitexco Tower, Q.1'),
          _buildRecentPlace('🏠', 'Nhà', 'Landmark 81, Bình Thạnh'),
          _buildRecentPlace('🛒', 'Coopmart Q.1', '189 Cống Quỳnh, Q.1'),
        ],
      ),
    );
  }

  Widget _buildServiceBtn(
    String emoji,
    String label,
    Color bgColor,
    Color borderColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPlace(String emoji, String name, String address) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/search'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  Text(address,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }
}
