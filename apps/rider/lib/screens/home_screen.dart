import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../providers/location_provider.dart';
import '../providers/active_order_provider.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentNavIndex = 0;

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
    final activeOrders = context.watch<ActiveOrderProvider>().activeOrders;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          // ========== MAP LAYER ==========
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(locProvider.lat, locProvider.lng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: ApiConfig.mapTileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.xebuonho.rider',
              ),
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

          // ========== TOP HEADER & SEARCH ==========
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // App bar row
                  Row(
                    children: [
                      _buildCircleBtn('☰', () => _scaffoldKey.currentState?.openDrawer()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Text('🏍️', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Vị trí hiện tại', style: TextStyle(fontSize: 10, color: AppColors.text3)),
                                    Text('Bitexco, 2 Hải Triều, Q.1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: AppColors.text3, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildCircleBtn('🔔', () => Navigator.pushNamed(context, '/notifications')),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
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
                            child: const Center(child: Text('📍', style: TextStyle(fontSize: 16))),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Bạn cần đi đâu, ăn gì, hay lái xe hộ?',
                              style: TextStyle(
                                color: AppColors.text3,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.blueBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Text('🔍', style: TextStyle(fontSize: 14))),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ========== LIVE ACTIVE ORDER FLOATING PILL ==========
                  if (activeOrders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildLiveOrderPill(activeOrders.first),
                  ],
                ],
              ),
            ),
          ),

          // ========== GPS CENTER BTN ==========
          Positioned(
            right: 16,
            bottom: 330,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(locProvider.lat, locProvider.lng), 16);
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
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(child: Text('🎯', style: TextStyle(fontSize: 18))),
              ),
            ),
          ),

          // ========== BOTTOM SHEET HUB ==========
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

  Widget _buildLiveOrderPill(ActiveOrderEntry order) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, order.routePath, arguments: order.routeArguments);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blueBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(order.emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(order.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(6)),
                        child: Text('${order.etaMinutes}p', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(order.statusText, style: const TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
              child: const Text('Xem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.blue, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 4,
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
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.text3.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ========== WALLET & DEALS BAR ==========
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text('💳', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ví Xebuonho', style: TextStyle(fontSize: 10, color: AppColors.text3)),
                    Text('500.000 đ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/top-up'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blueBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.blue),
                        SizedBox(width: 2),
                        Text('Nạp tiền', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.blue)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(height: 18, width: 1, color: AppColors.border),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/promotions'),
                  child: const Row(
                    children: [
                      Text('🎟️', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 4),
                      Text('5 Voucher', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.orange)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ========== 8 CORE SERVICES HUB GRID ==========
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildServiceBtn('🛵', 'Xe máy', AppColors.blueBg, AppColors.blue, () => Navigator.pushNamed(context, '/search')),
              _buildServiceBtn('🚗', 'Ô tô', AppColors.greenBg, AppColors.green, () => Navigator.pushNamed(context, '/search')),
              _buildServiceBtn('🍔', 'Đồ ăn', AppColors.orangeBg, AppColors.orange, () => Navigator.pushNamed(context, '/food')),
              _buildServiceBtn('🚙', 'Lái xe hộ', const Color(0xFF132F4C), const Color(0xFF38BDF8), () => Navigator.pushNamed(context, '/designated-driver'), badge: 'HOT'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildServiceBtn('🛒', 'Đi chợ', AppColors.purpleBg, AppColors.purple, () => Navigator.pushNamed(context, '/grocery')),
              _buildServiceBtn('📦', 'Giao hàng', const Color(0xFF0F3A4A), const Color(0xFF06B6D4), () => Navigator.pushNamed(context, '/delivery'), badge: 'MỚI'),
              _buildServiceBtn('📅', 'Đặt trước', const Color(0xFF312E81), const Color(0xFF818CF8), () => Navigator.pushNamed(context, '/schedule')),
              _buildServiceBtn('📋', 'Hoạt động', AppColors.bg3, AppColors.border, () => Navigator.pushNamed(context, '/activities')),
            ],
          ),
          const SizedBox(height: 14),

          // ========== DESIGNATED DRIVER PROMO BANNER ==========
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/designated-driver'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.green.withValues(alpha: 0.2), const Color(0xFF0D9488).withValues(alpha: 0.12)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Text('🛡️', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lái xe hộ — Bạn say tôi lái', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.text)),
                        Text('Tài xế chuyên nghiệp lái xe của bạn đưa bạn về nhà', style: TextStyle(fontSize: 10, color: AppColors.text3)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.green, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBtn(
    String emoji,
    String label,
    Color bgColor,
    Color borderColor,
    VoidCallback onTap, {
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badge == 'HOT' ? AppColors.red : AppColors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(badge, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text2),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentNavIndex,
      backgroundColor: AppColors.bg2,
      selectedItemColor: AppColors.blue,
      unselectedItemColor: AppColors.text3,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() => _currentNavIndex = index);
        switch (index) {
          case 0:
            break; // Already on home
          case 1:
            Navigator.pushNamed(context, '/activities');
            break;
          case 2:
            Navigator.pushNamed(context, '/payment');
            break;
          case 3:
            Navigator.pushNamed(context, '/chat');
            break;
          case 4:
            Navigator.pushNamed(context, '/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Trang chủ'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Hoạt động'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Ví & Pay'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Tin nhắn'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
      ],
    );
  }
}
