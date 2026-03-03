import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/booking_provider.dart';
import '../providers/location_provider.dart';
import '../services/geocoding_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _geocoding = GeocodingService();
  bool _isLoading = false;
  List<GeocodingResult> _results = [];

  final List<Map<String, dynamic>> _savedPlaces = [
    {'name': 'Nhà', 'address': 'Landmark 81, Bình Thạnh', 'emoji': '🏠', 'lat': 10.7942, 'lng': 106.7217},
    {'name': 'Văn phòng', 'address': 'Bitexco Tower, Q.1', 'emoji': '🏢', 'lat': 10.7716, 'lng': 106.7043},
  ];

  final List<Map<String, dynamic>> _popularPlaces = [
    {'name': 'Sân bay Tân Sơn Nhất', 'address': 'Tân Bình, TP.HCM', 'emoji': '✈️', 'lat': 10.8184, 'lng': 106.6588},
    {'name': 'Bến Thành Market', 'address': 'Quận 1, TP.HCM', 'emoji': '🏪', 'lat': 10.7721, 'lng': 106.6981},
    {'name': 'Landmark 81', 'address': 'Bình Thạnh, TP.HCM', 'emoji': '🏢', 'lat': 10.7942, 'lng': 106.7217},
    {'name': 'Saigon Center', 'address': '65 Lê Lợi, Q.1', 'emoji': '🛍️', 'lat': 10.7734, 'lng': 106.7000},
    {'name': 'Phú Mỹ Hưng', 'address': 'Quận 7, TP.HCM', 'emoji': '🌳', 'lat': 10.7290, 'lng': 106.7220},
    {'name': 'AEON Mall Bình Tân', 'address': 'Bình Tân, TP.HCM', 'emoji': '🏬', 'lat': 10.7442, 'lng': 106.6140},
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _geocoding.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final loc = context.read<LocationProvider>();
    final results = await _geocoding.search(
      query,
      lat: loc.lat,
      lng: loc.lng,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _selectPlace(String name, double lat, double lng) {
    final booking = context.read<BookingProvider>();
    booking.setDropoff(address: name, lat: lat, lng: lng);
    Navigator.pushNamed(context, '/booking');
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ========== Header ==========
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bg2,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.arrow_back, color: AppColors.text, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Chọn điểm đến',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pickup indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Text('🟢', style: TextStyle(fontSize: 10)),
                        SizedBox(width: 8),
                        Text('Vị trí hiện tại',
                          style: TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search input
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _search,
                    style: const TextStyle(color: AppColors.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nhập điểm đến...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('🔴', style: TextStyle(fontSize: 10)),
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _controller.clear();
                                _search('');
                              },
                              child: const Icon(Icons.close, color: AppColors.text3, size: 18),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading)
              const LinearProgressIndicator(
                backgroundColor: AppColors.bg2,
                color: AppColors.blue,
                minHeight: 2,
              ),

            // ========== Results ==========
            Expanded(
              child: hasQuery ? _buildSearchResults() : _buildDefaultContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Không tìm thấy "${_controller.text}"',
              style: const TextStyle(color: AppColors.text2, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Thử nhập từ khóa khác',
              style: TextStyle(color: AppColors.text3, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      itemBuilder: (_, idx) {
        final result = _results[idx];
        // Split display name for primary & secondary text
        final parts = result.displayName.split(',');
        final primary = result.name;
        final secondary = parts.length > 1
            ? parts.sublist(1).take(3).join(',').trim()
            : result.displayName;

        return GestureDetector(
          onTap: () => _selectPlace(result.displayName, result.lat, result.lng),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(result.emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(primary,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text(secondary,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.greenBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions, color: AppColors.green, size: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Saved places
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('ĐỊA ĐIỂM ĐÃ LƯU',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
        ),
        ..._savedPlaces.map((p) => _buildPlaceItem(p, isLarge: true)),
        const SizedBox(height: 16),

        // Popular places
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('ĐỊA ĐIỂM PHỔ BIẾN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
        ),
        ..._popularPlaces.map((p) => _buildPlaceItem(p)),
      ],
    );
  }

  Widget _buildPlaceItem(Map<String, dynamic> place, {bool isLarge = false}) {
    return GestureDetector(
      onTap: () => _selectPlace(place['name'], place['lat'], place['lng']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isLarge ? 12 : 10),
        decoration: BoxDecoration(
          color: isLarge ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isLarge ? Border.all(color: AppColors.border) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isLarge ? AppColors.blueBg : AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(place['emoji'], style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place['name'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(place['address'],
                    style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }
}
