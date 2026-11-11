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
    {'name': 'Nhà', 'address': 'Thị trấn Pơng Drang, Krông Búk', 'emoji': '🏠', 'lat': 12.9628, 'lng': 108.2465},
    {'name': 'Chợ Buôn Hồ', 'address': 'Đường Hùng Vương, TX. Buôn Hồ', 'emoji': '🛍️', 'lat': 12.9215, 'lng': 108.2520},
    {'name': 'Bệnh viện Buôn Hồ', 'address': 'Trần Hưng Đạo, Buôn Hồ', 'emoji': '🏥', 'lat': 12.9280, 'lng': 108.2560},
    {'name': 'Quảng trường Buôn Hồ', 'address': 'TX. Buôn Hồ, Đắk Lắk', 'emoji': '🌳', 'lat': 12.9230, 'lng': 108.2535},
  ];

  final List<Map<String, dynamic>> _recentTrips = [
    {'name': 'Pơng Drang', 'address': 'Huyện Krông Búk, Đắk Lắk', 'emoji': '🏙️', 'lat': 12.9628, 'lng': 108.2465, 'time': 'Vừa xong'},
    {'name': 'Xã Ea Siên', 'address': 'Thị xã Buôn Hồ, Đắk Lắk', 'emoji': '🏡', 'lat': 12.8500, 'lng': 108.3100, 'time': 'Hôm qua'},
    {'name': 'Ngã ba Pơng Drang', 'address': 'Quốc lộ 14, Krông Búk', 'emoji': '🚦', 'lat': 12.9640, 'lng': 108.2470, 'time': '2 ngày trước'},
    {'name': 'Bến xe Buôn Hồ', 'address': 'QL14, Phường Thiện An, Buôn Hồ', 'emoji': '🚌', 'lat': 12.9180, 'lng': 108.2505, 'time': '3 ngày trước'},
    {'name': 'Ngã 6 Buôn Ma Thuột', 'address': 'Tượng đài Chiến thắng BMT', 'emoji': '⭐', 'lat': 12.6840, 'lng': 108.0475, 'time': 'Tuần trước'},
  ];

  final List<Map<String, dynamic>> _popularPlaces = [
    {'name': 'Pơng Drang', 'address': 'Thị trấn Pơng Drang, Krông Búk', 'emoji': '🏙️', 'lat': 12.9628, 'lng': 108.2465},
    {'name': 'Chợ Buôn Hồ', 'address': 'Hùng Vương, TX. Buôn Hồ', 'emoji': '🛍️', 'lat': 12.9215, 'lng': 108.2520},
    {'name': 'Ngã ba Pơng Drang', 'address': 'QL14, Krông Búk', 'emoji': '🚦', 'lat': 12.9640, 'lng': 108.2470},
    {'name': 'Xã Ea Siên', 'address': 'TX. Buôn Hồ, Đắk Lắk', 'emoji': '🏡', 'lat': 12.8500, 'lng': 108.3100},
    {'name': 'Quảng trường Buôn Hồ', 'address': 'TX. Buôn Hồ, Đắk Lắk', 'emoji': '🌳', 'lat': 12.9230, 'lng': 108.2535},
    {'name': 'Sân bay Buôn Ma Thuột (BMV)', 'address': 'Hòa Thắng, TP. BMT', 'emoji': '✈️', 'lat': 12.6680, 'lng': 108.1200},
    {'name': 'Bến xe Buôn Hồ', 'address': 'QL14, TX. Buôn Hồ', 'emoji': '🚌', 'lat': 12.9180, 'lng': 108.2505},
    {'name': 'Bệnh viện Đa khoa Buôn Hồ', 'address': 'Trần Hưng Đạo, Buôn Hồ', 'emoji': '🏥', 'lat': 12.9280, 'lng': 108.2560},
  ];

  /// Filter saved + recent by query text with space and accent insensitivity (NFD/NFC)
  List<Map<String, dynamic>> _filterLocal(String q) {
    final lower = normalizeVietnameseText(q);
    if (lower.isEmpty) return [];
    final combined = <Map<String, dynamic>>[];
    for (final p in _savedPlaces) {
      final nameNorm = normalizeVietnameseText(p['name'].toString());
      final addrNorm = normalizeVietnameseText(p['address'].toString());
      if (nameNorm.contains(lower) || addrNorm.contains(lower)) {
        combined.add({...p, 'section': 'saved'});
      }
    }
    for (final p in _recentTrips) {
      final nameNorm = normalizeVietnameseText(p['name'].toString());
      final addrNorm = normalizeVietnameseText(p['address'].toString());
      if (nameNorm.contains(lower) || addrNorm.contains(lower)) {
        combined.add({...p, 'section': 'recent'});
      }
    }
    return combined;
  }

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
    final clean = query.trim();
    if (clean.length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    // 1. Instant local results (0ms - matches Pơng Drang, Buôn Hồ, Ea Siên, BMT, etc.)
    final instantMatches = _geocoding.searchLocal(clean);
    setState(() {
      _results = instantMatches;
      _isLoading = instantMatches.isEmpty;
    });

    // 2. Multi-tier online resolution (Gateway + OSM)
    final loc = context.read<LocationProvider>();
    final results = await _geocoding.search(
      clean,
      lat: loc.lat,
      lng: loc.lng,
    );

    if (mounted) {
      setState(() {
        if (results.isNotEmpty) {
          _results = results;
        }
        _isLoading = false;
      });
    }
  }

  void _selectPlace(String name, double lat, double lng) {
    final booking = context.read<BookingProvider>();
    final loc = context.read<LocationProvider>();
    if (booking.pickupAddress.isEmpty || booking.pickupAddress == 'Thị xã Buôn Hồ, Đắk Lắk') {
      booking.setPickup(
        address: loc.currentAddress.isNotEmpty ? loc.currentAddress : 'Vị trí hiện tại',
        lat: loc.lat,
        lng: loc.lng,
      );
    }
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
              decoration: BoxDecoration(
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
                          child: Center(
                            child: Icon(Icons.arrow_back, color: AppColors.text, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                    child: Row(
                      children: [
                        const Text('🟢', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 8),
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
                    style: TextStyle(color: AppColors.text, fontSize: 15),
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
                              child: Icon(Icons.close, color: AppColors.text3, size: 18),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading)
              LinearProgressIndicator(
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
    final q = _controller.text.trim();
    final localMatches = _filterLocal(q);

    if (_results.isEmpty && localMatches.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Không tìm thấy "$q"',
              style: TextStyle(color: AppColors.text2, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Thử nhập từ khóa khác',
              style: TextStyle(color: AppColors.text3, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Local matches (saved + recent) shown first
        if (localMatches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text('ĐỊA CHỈ CỦA BẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
          ),
          ...localMatches.map((p) => _buildLocalMatch(p)),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: AppColors.border),
            const SizedBox(height: 4),
          ],
        ],

        // Nominatim results
        if (_results.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text('KẾT QUẢ TÌM KIẾM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
          ),
          ..._results.map((result) {
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
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text(secondary,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppColors.text3)),
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
                      child: Icon(Icons.directions, color: AppColors.green, size: 16),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildLocalMatch(Map<String, dynamic> p) {
    final isSaved = p['section'] == 'saved';
    final time = p['time'] as String?;
    return GestureDetector(
      onTap: () => _selectPlace(p['address'], p['lat'], p['lng']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSaved ? AppColors.blueBg : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSaved ? AppColors.blue.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isSaved ? AppColors.blue.withValues(alpha: 0.2) : AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(p['emoji'], style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(p['name'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                      if (isSaved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                          child: Text('Đã lưu', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.blue)),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(p['address'], style: TextStyle(fontSize: 12, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (time != null)
                        Text(time, style: TextStyle(fontSize: 10, color: AppColors.text3)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Saved places
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text('ĐỊA CHỈ ĐÃ LƯU',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/saved-addresses'),
                child: Text('Xem tất cả', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blue)),
              ),
            ],
          ),
        ),
        ..._savedPlaces.map((p) => _buildPlaceItem(p, isLarge: true)),
        const SizedBox(height: 20),

        // Recent trips
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('GẦN ĐÂY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
        ),
        ..._recentTrips.map((p) => _buildRecentItem(p)),
        const SizedBox(height: 20),

        // Popular places
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('ĐỊA ĐIỂM PHỔ BIẾN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text3, letterSpacing: 1)),
        ),
        ..._popularPlaces.map((p) => _buildPlaceItem(p)),
      ],
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> place) {
    return GestureDetector(
      onTap: () => _selectPlace(place['address'], place['lat'], place['lng']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.orangeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(place['emoji'], style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place['name'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(place['address'], style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.history, color: AppColors.orange, size: 16),
                Text(place['time'], style: TextStyle(fontSize: 10, color: AppColors.text3)),
              ],
            ),
          ],
        ),
      ),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(place['address'],
                    style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }
}
