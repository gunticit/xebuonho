import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';
import 'package:intl/intl.dart';

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _cart = <CartItem>[];
  final _fmt = NumberFormat('#,###', 'vi_VN');
  Restaurant? _restaurant;

  String get _name => _restaurant?.name ?? 'Phở Thìn Bờ Hồ';
  String get _emoji => _restaurant?.image ?? '🍜';
  double get _rating => _restaurant?.rating ?? 4.8;
  int get _ratingCount => _restaurant?.ratingCount ?? 1250;
  String get _distance => _restaurant?.distance ?? '1.2 km';
  String get _deliveryTime => _restaurant?.deliveryTime ?? '20-30 phút';
  int get _deliveryFee => _restaurant?.deliveryFee ?? 15000;
  bool get _isOpen => _restaurant?.isOpen ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Restaurant && _restaurant == null) {
      setState(() => _restaurant = args);
    }
  }

  final _menuCategories = [
    MenuCategory(name: 'Bán chạy 🔥', items: [
      MenuItem(id: '1', name: 'Phở tái nạm', description: 'Phở bò truyền thống, nước dùng ngọt', price: 55000),
      MenuItem(id: '2', name: 'Phở bò viên', description: 'Bò viên tươi, rau thơm', price: 50000),
      MenuItem(id: '3', name: 'Phở gà', description: 'Gà ta xé, hành phi giòn', price: 48000),
    ]),
    MenuCategory(name: 'Món thêm', items: [
      MenuItem(id: '4', name: 'Nem rán', description: '4 miếng, chấm nước mắm', price: 30000),
      MenuItem(id: '5', name: 'Gỏi cuốn', description: '2 cuốn, tôm thịt', price: 25000),
    ]),
    MenuCategory(name: 'Đồ uống 🥤', items: [
      MenuItem(id: '6', name: 'Trà đá', description: '', price: 5000),
      MenuItem(id: '7', name: 'Nước chanh', description: 'Chanh tươi', price: 15000),
      MenuItem(id: '8', name: 'Coca-Cola', description: 'Lon 330ml', price: 12000),
    ]),
  ];

  int get _totalItems => _cart.fold(0, (sum, c) => sum + c.quantity);
  int get _totalPrice => _cart.fold(0, (sum, c) => sum + c.total);

  void _addToCart(MenuItem item) {
    setState(() {
      final existing = _cart.indexWhere((c) => c.item.id == item.id);
      if (existing >= 0) {
        _cart[existing].quantity++;
      } else {
        _cart.add(CartItem(item: item));
      }
    });
  }

  void _removeFromCart(MenuItem item) {
    setState(() {
      final existing = _cart.indexWhere((c) => c.item.id == item.id);
      if (existing >= 0) {
        if (_cart[existing].quantity > 1) {
          _cart[existing].quantity--;
        } else {
          _cart.removeAt(existing);
        }
      }
    });
  }

  int _getQuantity(String itemId) {
    final idx = _cart.indexWhere((c) => c.item.id == itemId);
    return idx >= 0 ? _cart[idx].quantity : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: AppColors.bg2,
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.orange.withValues(alpha: 0.2), AppColors.bg2],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 72))),
              ),
              title: Text(_name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          // Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('⭐ $_rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      Text(' (${_fmt.format(_ratingCount)} đánh giá)', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _isOpen ? AppColors.greenBg : AppColors.redBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(_isOpen ? '🟢 Đang mở' : '🔴 Đã đóng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isOpen ? AppColors.green : AppColors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('🕐 $_deliveryTime  •  📍 $_distance  •  🚚 Ship ${(_deliveryFee / 1000).toStringAsFixed(0)}k', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                  const SizedBox(height: 16),
                  Divider(color: AppColors.border),
                ],
              ),
            ),
          ),

          // Menu
          ..._menuCategories.expand((cat) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(cat.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildMenuItem(cat.items[i]),
                childCount: cat.items.length,
              ),
            ),
          ]),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Cart bar
      bottomSheet: _totalItems > 0 ? Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(10)),
              child: Text('🛒 $_totalItems', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('${_fmt.format(_totalPrice)}đ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/checkout', arguments: {
                'cart': _cart,
                'restaurantName': _name,
                'restaurantEmoji': _emoji,
                'deliveryTime': _deliveryTime,
                'distance': _distance,
                'deliveryFee': _deliveryFee,
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                child: const Text('Đặt món', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ) : null,
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    final qty = _getQuantity(item.id);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: qty > 0 ? AppColors.orangeBg : AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: qty > 0 ? AppColors.orange.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                if (item.description.isNotEmpty)
                  Text(item.description, style: TextStyle(fontSize: 12, color: AppColors.text3)),
                const SizedBox(height: 4),
                Text('${_fmt.format(item.price)}đ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (qty > 0)
            Row(
              children: [
                _buildQtyBtn(Icons.remove, () => _removeFromCart(item)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$qty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
                _buildQtyBtn(Icons.add, () => _addToCart(item)),
              ],
            )
          else
            GestureDetector(
              onTap: () => _addToCart(item),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.text, size: 16),
      ),
    );
  }
}
