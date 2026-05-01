import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  String _selectedCategory = 'all';
  final _searchCtrl = TextEditingController();

  final _categories = [
    {'id': 'all', 'name': 'Tất cả', 'emoji': '🔥'},
    {'id': 'pho', 'name': 'Phở', 'emoji': '🍜'},
    {'id': 'rice', 'name': 'Cơm', 'emoji': '🍚'},
    {'id': 'banhmi', 'name': 'Bánh mì', 'emoji': '🥖'},
    {'id': 'coffee', 'name': 'Trà sữa', 'emoji': '🧋'},
    {'id': 'pizza', 'name': 'Pizza', 'emoji': '🍕'},
    {'id': 'dessert', 'name': 'Tráng miệng', 'emoji': '🍰'},
  ];

  final _restaurants = [
    Restaurant(id: '1', name: 'Phở Thìn Bờ Hồ', image: '🍜', category: 'pho', rating: 4.8, ratingCount: 1250, distance: '1.2 km', deliveryTime: '20-30 phút', deliveryFee: 15000, tags: ['Bán chạy', 'Ưa chuộng']),
    Restaurant(id: '2', name: 'Bánh Mì Huỳnh Hoa', image: '🥖', category: 'banhmi', rating: 4.9, ratingCount: 3400, distance: '0.8 km', deliveryTime: '15-25 phút', deliveryFee: 12000, tags: ['Top 1', 'Huyền thoại']),
    Restaurant(id: '3', name: 'Cơm Tấm Bụi Sài Gòn', image: '🍚', category: 'rice', rating: 4.6, ratingCount: 890, distance: '2.1 km', deliveryTime: '25-35 phút', deliveryFee: 18000, tags: ['Mới']),
    Restaurant(id: '4', name: 'Highlands Coffee', image: '☕', category: 'coffee', rating: 4.3, ratingCount: 2100, distance: '0.5 km', deliveryTime: '10-20 phút', deliveryFee: 10000, tags: ['Gần bạn']),
    Restaurant(id: '5', name: 'Pizza 4P\'s', image: '🍕', category: 'pizza', rating: 4.7, ratingCount: 5600, distance: '3.0 km', deliveryTime: '30-45 phút', deliveryFee: 25000, tags: ['Premium', 'Best seller']),
    Restaurant(id: '6', name: 'Phúc Long', image: '🧋', category: 'coffee', rating: 4.5, ratingCount: 1800, distance: '1.5 km', deliveryTime: '15-25 phút', deliveryFee: 12000, tags: ['Trà sữa ngon']),
  ];

  List<Restaurant> get _filtered {
    var list = _restaurants;
    if (_selectedCategory != 'all') {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Đặt đồ ăn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Tìm nhà hàng, món ăn...',
                prefixIcon: Icon(Icons.search, color: AppColors.text3),
              ),
            ),
          ),

          // Categories
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: _categories.map((c) {
                final isSelected = _selectedCategory == c['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c['id'] as String),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.orangeBg : AppColors.bg2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.orange : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(c['emoji'] as String, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(c['name'] as String, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.orange : AppColors.text2,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Restaurant list
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text('Không tìm thấy', style: TextStyle(color: AppColors.text3)),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildRestaurant(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurant(Restaurant r) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-detail', arguments: r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(r.image, style: const TextStyle(fontSize: 32))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('${r.rating}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      Text(' (${r.ratingCount})', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                      const SizedBox(width: 8),
                      Text('• ${r.distance}', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('🕐 ${r.deliveryTime}', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                      const Spacer(),
                      Text('Ship ${(r.deliveryFee / 1000).toStringAsFixed(0)}k',
                        style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (r.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: r.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orangeBg, borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.orange)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
