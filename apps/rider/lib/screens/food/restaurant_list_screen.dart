import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_icons.dart';
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
    {'id': 'all', 'name': 'Tất cả', 'icon': AppIcons.fire},
    {'id': 'pho', 'name': 'Phở', 'icon': Icons.ramen_dining_rounded},
    {'id': 'rice', 'name': 'Cơm', 'icon': Icons.rice_bowl_rounded},
    {'id': 'banhmi', 'name': 'Bánh mì', 'icon': Icons.bakery_dining_rounded},
    {'id': 'coffee', 'name': 'Trà sữa & Cafe', 'icon': Icons.local_cafe_rounded},
    {'id': 'pizza', 'name': 'Pizza', 'icon': Icons.local_pizza_rounded},
    {'id': 'dessert', 'name': 'Tráng miệng', 'icon': Icons.cake_rounded},
  ];

  final _restaurants = [
    Restaurant(id: '1', name: 'Phở Thìn Bờ Hồ', image: 'pho', category: 'pho', rating: 4.8, ratingCount: 1250, distance: '1.2 km', deliveryTime: '20-30 phút', deliveryFee: 15000, tags: ['Bán chạy', 'Ưa chuộng']),
    Restaurant(id: '2', name: 'Bánh Mì Huỳnh Hoa', image: 'banhmi', category: 'banhmi', rating: 4.9, ratingCount: 3400, distance: '0.8 km', deliveryTime: '15-25 phút', deliveryFee: 12000, tags: ['Top 1', 'Huyền thoại']),
    Restaurant(id: '3', name: 'Cơm Tấm Bụi Sài Gòn', image: 'rice', category: 'rice', rating: 4.6, ratingCount: 890, distance: '2.1 km', deliveryTime: '25-35 phút', deliveryFee: 18000, tags: ['Mới']),
    Restaurant(id: '4', name: 'Highlands Coffee', image: 'coffee', category: 'coffee', rating: 4.3, ratingCount: 2100, distance: '0.5 km', deliveryTime: '10-20 phút', deliveryFee: 10000, tags: ['Gần bạn']),
    Restaurant(id: '5', name: 'Pizza 4P\'s', image: 'pizza', category: 'pizza', rating: 4.7, ratingCount: 5600, distance: '3.0 km', deliveryTime: '30-45 phút', deliveryFee: 25000, tags: ['Premium', 'Best seller']),
    Restaurant(id: '6', name: 'Phúc Long Tea & Coffee', image: 'tea', category: 'coffee', rating: 4.5, ratingCount: 1800, distance: '1.5 km', deliveryTime: '15-25 phút', deliveryFee: 12000, tags: ['Trà sữa ngon']),
  ];

  IconData _getRestaurantIcon(String type) {
    switch (type) {
      case 'pho':
        return Icons.ramen_dining_rounded;
      case 'banhmi':
        return Icons.bakery_dining_rounded;
      case 'rice':
        return Icons.rice_bowl_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'pizza':
        return Icons.local_pizza_rounded;
      case 'tea':
        return Icons.local_drink_rounded;
      default:
        return AppIcons.food;
    }
  }

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
        title: Text('Đặt đồ ăn & Thức uống', style: AppTextStyles.heading3),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Tìm nhà hàng, món ăn yêu thích...',
                prefixIcon: const Icon(AppIcons.search, color: AppColors.text3, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: isSelected ? AppColors.orange : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(c['icon'] as IconData, size: 16, color: isSelected ? AppColors.orange : AppColors.text3),
                        const SizedBox(width: 6),
                        Text(
                          c['name'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.orange : AppColors.text2,
                          ),
                        ),
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
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconContainer(
                          icon: AppIcons.search,
                          color: AppColors.text3,
                          size: 60,
                          iconSize: 28,
                          borderRadius: AppRadius.lg,
                        ),
                        const SizedBox(height: 12),
                        Text('Không tìm thấy quán ăn phù hợp', style: AppTextStyles.body2),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildRestaurant(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurant(Restaurant r) {
    final icon = _getRestaurantIcon(r.image);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-detail', arguments: r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            IconContainer(
              icon: icon,
              color: AppColors.orange,
              size: 70,
              iconSize: 34,
              borderRadius: AppRadius.md,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: AppTextStyles.heading4.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(AppIcons.star, size: 14, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text('${r.rating}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      Text(' (${r.ratingCount})', style: AppTextStyles.caption),
                      const SizedBox(width: 8),
                      Text('• ${r.distance}', style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(AppIcons.timer, size: 13, color: AppColors.text3),
                      const SizedBox(width: 4),
                      Text(r.deliveryTime, style: AppTextStyles.caption),
                      const Spacer(),
                      Text(
                        'Ship ${(r.deliveryFee / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (r.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: r.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orangeBg,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.orange)),
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
