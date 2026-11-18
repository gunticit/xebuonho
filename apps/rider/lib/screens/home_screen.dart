import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../config/app_icons.dart';
import '../providers/location_provider.dart';
import '../providers/active_order_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/service_grid_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentNavIndex = 0;
  bool _hasInitialMapCentered = false;
  bool _isMenuExpanded = true;

  Future<void> _recenterToCurrentLocation() async {
    final loc = context.read<LocationProvider>();
    _mapController.move(LatLng(loc.lat, loc.lng), 16);
    await loc.fetchLocation();
    if (mounted) {
      _mapController.move(LatLng(loc.lat, loc.lng), 16);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = context.read<LocationProvider>();
      loc.fetchLocation().then((_) {
        if (mounted && loc.currentPosition != null && !_hasInitialMapCentered) {
          _hasInitialMapCentered = true;
          _mapController.move(LatLng(loc.lat, loc.lng), 15);
        }
      });
    });
  }

  void _onBottomNavTapped(int index) {
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
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = context.watch<LocationProvider>();
    final activeOrders = context.watch<ActiveOrderProvider>().activeOrders;

    if (!_hasInitialMapCentered && locProvider.currentPosition != null) {
      _hasInitialMapCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(LatLng(locProvider.lat, locProvider.lng), 15);
        }
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // ========== MAP LAYER ==========
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(locProvider.lat, locProvider.lng),
              initialZoom: 15,
              onTap: (tapPosition, point) {
                context.read<LocationProvider>().selectLocationOnMap(point.latitude, point.longitude);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.card,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.green),
                    ),
                    content: Row(
                      children: [
                        const Icon(AppIcons.pin, color: AppColors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Đã ghim điểm đón trên bản đồ. Bấm nút định vị để quay lại GPS.',
                            style: AppTextStyles.body2.copyWith(color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(locProvider.lat, locProvider.lng),
                    radius: (locProvider.currentPosition?.accuracy ?? 25.0).clamp(10.0, 90.0),
                    useRadiusInMeter: true,
                    color: (locProvider.isManualPin ? AppColors.green : AppColors.blue).withValues(alpha: 0.12),
                    borderColor: (locProvider.isManualPin ? AppColors.green : AppColors.blue).withValues(alpha: 0.45),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(locProvider.lat, locProvider.lng),
                    width: 52,
                    height: 52,
                    child: _buildUserMarker(locProvider.isManualPin),
                  ),
                ],
              ),
            ],
          ),

          // ========== TOP HEADER & SEARCH ==========
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // App bar row
                  Row(
                    children: [
                      _buildCircleActionBtn(
                        icon: AppIcons.menu,
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _recenterToCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.card.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppShadows.subtle,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  locProvider.isManualPin ? AppIcons.pin : AppIcons.bike,
                                  color: locProvider.isManualPin ? AppColors.green : AppColors.blue,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        locProvider.isManualPin ? 'Điểm đón đã ghim' : 'Vị trí hiện tại',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: locProvider.isManualPin ? FontWeight.w600 : FontWeight.normal,
                                          color: locProvider.isManualPin ? AppColors.green : AppColors.text3,
                                        ),
                                      ),
                                      Text(
                                        locProvider.loading
                                            ? 'Đang xác định vị trí...'
                                            : locProvider.currentAddress,
                                        style: AppTextStyles.body1.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  locProvider.isManualPin ? AppIcons.edit : AppIcons.myLocation,
                                  color: locProvider.isManualPin ? AppColors.green : AppColors.blue,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildCircleActionBtn(
                        icon: AppIcons.notifications,
                        onTap: () => Navigator.pushNamed(context, '/notifications'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Modern Search Bar
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.medium,
                      ),
                      child: Row(
                        children: [
                          IconContainer(
                            icon: AppIcons.pickup,
                            color: AppColors.green,
                            size: 34,
                            iconSize: 18,
                            borderRadius: AppRadius.sm,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bạn cần đi đâu, ăn gì, hay lái xe hộ?',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.text3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconContainer(
                            icon: AppIcons.search,
                            color: AppColors.blue,
                            size: 34,
                            iconSize: 18,
                            borderRadius: AppRadius.sm,
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.fastOutSlowIn,
            right: 16,
            bottom: _isMenuExpanded ? 415 : 125,
            child: GestureDetector(
              onTap: _recenterToCurrentLocation,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.medium,
                ),
                child: const Center(
                  child: Icon(AppIcons.target, color: AppColors.blue, size: 22),
                ),
              ),
            ),
          ),

          // ========== BOTTOM SHEET HUB & FLOATING NAV ==========
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBottomSheet(context),
                ModernBottomNav(
                  currentIndex: _currentNavIndex,
                  onTap: _onBottomNavTapped,
                ),
              ],
            ),
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.6), width: 1.5),
          boxShadow: AppShadows.glow(AppColors.blue),
        ),
        child: Row(
          children: [
            IconContainer(
              icon: AppIcons.delivery,
              color: AppColors.blue,
              size: 36,
              iconSize: 20,
              borderRadius: AppRadius.md,
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
                        child: Text(
                          order.title,
                          style: AppTextStyles.heading4.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orangeBg,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '${order.etaMinutes}p',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.statusText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text('Xem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMarker([bool isManual = false]) {
    final color = isManual ? AppColors.green : AppColors.blue;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2.5),
        boxShadow: AppShadows.glow(color),
      ),
      child: Center(
        child: Icon(
          isManual ? AppIcons.pin : AppIcons.bike,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCircleActionBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.subtle,
        ),
        child: Center(
          child: Icon(icon, color: AppColors.text, size: 20),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    void handleDragUpdate(DragUpdateDetails details) {
      if (details.primaryDelta! > 4 && _isMenuExpanded) {
        setState(() => _isMenuExpanded = false);
      } else if (details.primaryDelta! < -4 && !_isMenuExpanded) {
        setState(() => _isMenuExpanded = true);
      }
    }

    void handleDragEnd(DragEndDetails details) {
      final velocity = details.primaryVelocity ?? 0;
      if (velocity > 200 && _isMenuExpanded) {
        setState(() => _isMenuExpanded = false);
      } else if (velocity < -200 && !_isMenuExpanded) {
        setState(() => _isMenuExpanded = true);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: handleDragUpdate,
      onVerticalDragEnd: handleDragEnd,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.bg2.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.strong,
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== INTERACTIVE DRAG HANDLE ==========
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _isMenuExpanded = !_isMenuExpanded);
              },
              onVerticalDragUpdate: handleDragUpdate,
              onVerticalDragEnd: handleDragEnd,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.transparent,
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.text3.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isMenuExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: AppColors.text3,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isMenuExpanded ? 'Thu gọn menu' : 'Mở rộng dịch vụ',
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ========== COMPACT MINI HUB (WHEN COLLAPSED) ==========
            if (!_isMenuExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(AppIcons.wallet, size: 16, color: AppColors.green),
                          const SizedBox(width: 6),
                          Text('500.000đ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.text)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniShortcut(AppIcons.bike, 'Xe máy', AppColors.blue, () => Navigator.pushNamed(context, '/search')),
                          _buildMiniShortcut(AppIcons.car, 'Ô tô', AppColors.green, () => Navigator.pushNamed(context, '/search')),
                          _buildMiniShortcut(AppIcons.food, 'Đồ ăn', AppColors.orange, () => Navigator.pushNamed(context, '/food')),
                          _buildMiniShortcut(AppIcons.designatedDriver, 'Lái hộ', const Color(0xFF38BDF8), () => Navigator.pushNamed(context, '/designated-driver')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ========== FULL MENU EXPANDED CONTENT ==========
            if (_isMenuExpanded) ...[
              // ========== WALLET & DEALS BAR ==========
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppGradients.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconContainer(
                      icon: AppIcons.wallet,
                      color: AppColors.green,
                      size: 36,
                      iconSize: 20,
                      borderRadius: AppRadius.sm,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ví Xebuonho', style: AppTextStyles.caption),
                        Text('500.000 đ', style: AppTextStyles.heading4.copyWith(fontSize: 14)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/top-up'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.blueBg,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(AppIcons.add, size: 14, color: AppColors.blue),
                            const SizedBox(width: 4),
                            Text('Nạp tiền', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.blue)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 18, width: 1, color: AppColors.border),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/promotions'),
                      child: Row(
                        children: [
                          const Icon(AppIcons.voucher, size: 16, color: AppColors.orange),
                          const SizedBox(width: 4),
                          Text('5 Voucher', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.orange)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ========== 8 CORE SERVICES HUB GRID ==========
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ServiceGridButton(icon: AppIcons.bike, label: 'Xe máy', color: AppColors.blue, onTap: () => Navigator.pushNamed(context, '/search')),
                  ServiceGridButton(icon: AppIcons.car, label: 'Ô tô', color: AppColors.green, onTap: () => Navigator.pushNamed(context, '/search')),
                  ServiceGridButton(icon: AppIcons.food, label: 'Đồ ăn', color: AppColors.orange, onTap: () => Navigator.pushNamed(context, '/food')),
                  ServiceGridButton(icon: AppIcons.designatedDriver, label: 'Lái xe hộ', color: const Color(0xFF38BDF8), onTap: () => Navigator.pushNamed(context, '/designated-driver'), badge: 'HOT'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ServiceGridButton(icon: AppIcons.grocery, label: 'Đi chợ', color: AppColors.purple, onTap: () => Navigator.pushNamed(context, '/grocery')),
                  ServiceGridButton(icon: AppIcons.delivery, label: 'Giao hàng', color: AppColors.cyan, onTap: () => Navigator.pushNamed(context, '/delivery'), badge: 'MỚI'),
                  ServiceGridButton(icon: AppIcons.schedule, label: 'Đặt trước', color: const Color(0xFF818CF8), onTap: () => Navigator.pushNamed(context, '/schedule')),
                  ServiceGridButton(icon: AppIcons.activities, label: 'Hoạt động', color: AppColors.text2, onTap: () => Navigator.pushNamed(context, '/activities')),
                ],
              ),
              const SizedBox(height: 12),

              // ========== DESIGNATED DRIVER PROMO BANNER ==========
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/designated-driver'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.green.withValues(alpha: 0.2), const Color(0xFF0D9488).withValues(alpha: 0.12)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      IconContainer(
                        icon: AppIcons.shield,
                        color: AppColors.green,
                        size: 38,
                        iconSize: 22,
                        borderRadius: AppRadius.md,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lái xe hộ — Bạn say tôi lái', style: AppTextStyles.heading4.copyWith(fontSize: 13)),
                            Text('Tài xế chuyên nghiệp lái xe của bạn đưa bạn về an toàn', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const Icon(AppIcons.forward, color: AppColors.green, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniShortcut(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
