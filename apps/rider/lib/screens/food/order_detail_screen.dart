import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';
import '../../services/sepay_service.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _fmt = NumberFormat('#,###', 'vi_VN');

  String _orderId = '';
  String _restaurantName = 'Phở Thìn Bờ Hồ';
  String _restaurantEmoji = '🍜';
  List<CartItem> _items = [];
  int _subtotal = 188000;
  int _deliveryFee = 15000;
  int _discount = 20000;
  int _total = 183000;
  String _paymentMethod = 'Ví Xebuonho';
  String _address = 'Nhà — 123 Nguyễn Huệ, Q.1, TP.HCM';
  DateTime _createdAt = DateTime.now();
  OrderStatus _status = OrderStatus.delivered;
  int? _userRating;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _restaurantName = args['restaurantName'] as String? ?? _restaurantName;
      _restaurantEmoji = args['restaurantEmoji'] as String? ?? _restaurantEmoji;
      _items = List<CartItem>.from(args['cart'] ?? []);
      _subtotal = args['subtotal'] as int? ?? _subtotal;
      _deliveryFee = args['deliveryFee'] as int? ?? _deliveryFee;
      _discount = args['discount'] as int? ?? _discount;
      _total = args['total'] as int? ?? _total;
      _paymentMethod = args['paymentMethod'] as String? ?? _paymentMethod;
      _address = args['address'] as String? ?? _address;
      _orderId = args['orderId'] as String? ?? SepayService.generateOrderId();
      _userRating = args['rating'] as int?;
      if (args['status'] is OrderStatus) {
        _status = args['status'] as OrderStatus;
      }
    } else {
      _orderId = 'XBN-240304-001';
      _items = [
        CartItem(item: MenuItem(id: '1', name: 'Phở tái nạm', description: '', price: 55000), quantity: 2),
        CartItem(item: MenuItem(id: '3', name: 'Phở gà', description: '', price: 48000)),
        CartItem(item: MenuItem(id: '7', name: 'Nước chanh', description: '', price: 15000), quantity: 2),
      ];
    }
  }

  bool get _isCompleted => _status == OrderStatus.delivered;
  bool get _isCancelled => _status == OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final reorderArgs = {
      'cart': _items,
      'restaurantName': _restaurantName,
      'restaurantEmoji': _restaurantEmoji,
      'deliveryFee': _deliveryFee,
      'deliveryTime': '20-30 phút',
      'distance': '1.2 km',
    };
    final shareArgs = {
      'cart': _items,
      'restaurantName': _restaurantName,
      'total': _total,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Chi tiết đơn hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusBanner(),
          const SizedBox(height: 16),
          _buildRestaurantCard(),
          const SizedBox(height: 16),
          _buildSection('🛒 Các món đã đặt'),
          ..._items.map((c) => _buildItemRow('${c.quantity}x', c.item.name, c.total)),
          if (_items.isEmpty)
            _buildItemRow('—', 'Không có món', 0),
          const SizedBox(height: 16),
          _buildSection('📍 Giao đến'),
          _buildAddressCard(),
          const SizedBox(height: 16),
          if (!_isCancelled) ...[
            _buildSection('🏍️ Tài xế'),
            _buildDriverCard(),
            const SizedBox(height: 16),
          ],
          _buildSection('💰 Thanh toán'),
          _buildPaymentCard(),
          const SizedBox(height: 24),
          _buildActions(reorderArgs, shareArgs),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final color = _isCompleted ? AppColors.green : (_isCancelled ? AppColors.red : AppColors.orange);
    final bg = _isCompleted ? AppColors.greenBg : (_isCancelled ? AppColors.redBg : AppColors.orangeBg);
    final emoji = _status.emoji;
    final label = _isCompleted ? 'Đã giao thành công' : (_isCancelled ? 'Đã hủy' : _status.label);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text('Đơn #$_orderId', style: TextStyle(fontSize: 12, color: AppColors.text3)),
            Text(DateFormat('dd/MM/yyyy — HH:mm').format(_createdAt), style: TextStyle(fontSize: 12, color: AppColors.text3)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRestaurantCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(_restaurantEmoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_restaurantName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          Row(children: [
            Text('⭐ 4.8', style: TextStyle(fontSize: 12, color: AppColors.orange)),
            Text('  •  📍 1.2 km', style: TextStyle(fontSize: 12, color: AppColors.text3)),
          ]),
        ])),
        Icon(Icons.chevron_right, color: AppColors.text3, size: 20),
      ]),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Text('🏠', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(_address, style: TextStyle(fontSize: 13, color: AppColors.text2))),
      ]),
    );
  }

  Widget _buildDriverCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('T', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trần Văn Tài', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text('⭐ 4.9  •  59F1-12345', style: TextStyle(fontSize: 12, color: AppColors.text3)),
        ])),
        if (_userRating != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Text('⭐', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text('${_userRating} sao', style: TextStyle(fontSize: 11, color: AppColors.orange, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        _buildPriceRow('Tạm tính', '${_fmt.format(_subtotal)}đ'),
        _buildPriceRow('Phí giao hàng', '${_fmt.format(_deliveryFee)}đ'),
        if (_discount > 0)
          _buildPriceRow('Giảm giá', '-${_fmt.format(_discount)}đ', isGreen: true),
        const Divider(color: AppColors.border, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tổng cộng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
          Text('${_fmt.format(_total)}đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.orange)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('💳', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(_paymentMethod, style: TextStyle(fontSize: 13, color: AppColors.text3)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(6)),
            child: Text('Đã thanh toán', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildActions(Map<String, dynamic> reorderArgs, Map<String, dynamic> shareArgs) {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/share-bill', arguments: shareArgs),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
            ),
            child: Center(child: Text('🧾 Chia bill', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.purple))),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            _items.isEmpty ? '/food' : '/checkout',
            arguments: _items.isEmpty ? null : reorderArgs,
          ),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.green, Color(0xFF2ECC71)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('🔄 Đặt lại', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
    );
  }

  Widget _buildItemRow(String qty, String name, int price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(qty, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: TextStyle(fontSize: 14, color: AppColors.text))),
        Text('${_fmt.format(price)}đ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
      ]),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.text2)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isGreen ? AppColors.green : AppColors.text)),
      ]),
    );
  }
}
