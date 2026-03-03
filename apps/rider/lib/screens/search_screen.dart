import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/booking_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  final List<Map<String, dynamic>> _popularPlaces = [
    {'name': 'Sân bay Tân Sơn Nhất', 'address': 'Tân Bình, TP.HCM', 'emoji': '✈️', 'lat': 10.8184, 'lng': 106.6588},
    {'name': 'Bến Thành Market', 'address': 'Quận 1, TP.HCM', 'emoji': '🏪', 'lat': 10.7721, 'lng': 106.6981},
    {'name': 'Landmark 81', 'address': 'Bình Thạnh, TP.HCM', 'emoji': '🏢', 'lat': 10.7942, 'lng': 106.7217},
    {'name': 'Saigon Center', 'address': '65 Lê Lợi, Q.1', 'emoji': '🛍️', 'lat': 10.7734, 'lng': 106.7000},
    {'name': 'Phú Mỹ Hưng', 'address': 'Quận 7, TP.HCM', 'emoji': '🌳', 'lat': 10.7290, 'lng': 106.7220},
    {'name': 'AEON Mall Bình Tân', 'address': 'Bình Tân, TP.HCM', 'emoji': '🏬', 'lat': 10.7442, 'lng': 106.6140},
    {'name': 'Bệnh viện Chợ Rẫy', 'address': '201 Nguyễn Chí Thanh, Q.5', 'emoji': '🏥', 'lat': 10.7558, 'lng': 106.6601},
    {'name': 'Thảo Cầm Viên', 'address': 'Quận 1, TP.HCM', 'emoji': '🦁', 'lat': 10.7879, 'lng': 106.7057},
  ];

  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = _popularPlaces;
    _focusNode.requestFocus();
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _popularPlaces;
      } else {
        _filtered = _popularPlaces
            .where((p) =>
                p['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
                p['address'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectPlace(Map<String, dynamic> place) {
    final booking = context.read<BookingProvider>();
    booking.setDropoff(
      address: place['name'],
      lat: place['lat'],
      lng: place['lng'],
    );
    Navigator.pushNamed(context, '/booking');
  }

  @override
  Widget build(BuildContext context) {
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
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.arrow_back,
                                color: AppColors.text, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Chọn điểm đến',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pickup indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.green.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Text('🟢', style: TextStyle(fontSize: 10)),
                        SizedBox(width: 8),
                        Text(
                          'Vị trí hiện tại',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search input
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _search,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nhập điểm đến...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child:
                            Text('🔴', style: TextStyle(fontSize: 10)),
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _controller.clear();
                                _search('');
                              },
                              child: const Icon(Icons.close,
                                  color: AppColors.text3, size: 18),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // ========== Results ==========
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Saved places
                  if (_controller.text.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'ĐỊA ĐIỂM ĐÃ LƯU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    _buildSavedPlace(
                      '🏠', 'Nhà', 'Landmark 81, Bình Thạnh',
                      10.7942, 106.7217,
                    ),
                    _buildSavedPlace(
                      '🏢', 'Văn phòng', 'Bitexco Tower, Q.1',
                      10.7716, 106.7043,
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'ĐỊA ĐIỂM PHỔ BIẾN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],

                  // Search results / Popular
                  ..._filtered.map((place) => _buildPlaceItem(place)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlace(
      String emoji, String name, String address, double lat, double lng) {
    return GestureDetector(
      onTap: () => _selectPlace({
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
      }),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blueBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
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
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceItem(Map<String, dynamic> place) {
    return GestureDetector(
      onTap: () => _selectPlace(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                child: Text(place['emoji'],
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    place['address'],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.text3),
                  ),
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
