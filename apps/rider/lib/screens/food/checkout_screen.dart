import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';
import 'package:intl/intl.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _fmt = NumberFormat('#,###', 'vi_VN');
  final _noteCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();

  String _selectedPayment = 'wallet';
  String _selectedAddress = 'Nhà — 123 Nguyễn Huệ, Q.1';
  bool _promoApplied = false;

  // Data from restaurant detail (received via arguments)
  late List<CartItem> _items;
  late String _restaurantName;
  late String _restaurantEmoji;
  late String _deliveryTime;
  late String _distance;
  late int _deliveryFee;
  bool _dataLoaded = false;

  int get _subtotal => _items.fold(0, (s, c) => s + c.total);
  int get _discount => _promoApplied ? 20000 : 0;
  int get _total => _subtotal + _deliveryFee - _discount;

  final _addresses = [
    {'label': 'Nhà', 'address': '123 Nguyễn Huệ, Q.1', 'emoji': '🏠'},
    {'label': 'Công ty', 'address': '456 Lê Lợi, Q.3', 'emoji': '🏢'},
    {'label': 'Gym', 'address': '789 Pasteur, Q.1', 'emoji': '💪'},
  ];

  final _payments = [
    {'id': 'wallet', 'name': 'Ví Xebuonho', 'emoji': '👛', 'subtitle': '150.000đ'},
    {'id': 'momo', 'name': 'MoMo', 'emoji': '🟣', 'subtitle': '****1234'},
    {'id': 'zalopay', 'name': 'ZaloPay', 'emoji': '🔵', 'subtitle': '****5678'},
    {'id': 'cash', 'name': 'Tiền mặt', 'emoji': '💵', 'subtitle': 'Trả khi nhận'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _items = List<CartItem>.from(args['cart'] ?? []);
        _restaurantName = args['restaurantName'] ?? 'Nhà hàng';
        _restaurantEmoji = args['restaurantEmoji'] ?? '🍜';
        _deliveryTime = args['deliveryTime'] ?? '20-30 phút';
        _distance = args['distance'] ?? '1.0 km';
        _deliveryFee = args['deliveryFee'] ?? 15000;
      } else {
        // Fallback demo data
        _items = [
          CartItem(item: MenuItem(id: '1', name: 'Phở tái nạm', description: 'Phở bò truyền thống', price: 55000), quantity: 2),
          CartItem(item: MenuItem(id: '3', name: 'Phở gà', description: 'Gà ta xé, hành phi', price: 48000)),
          CartItem(item: MenuItem(id: '7', name: 'Nước chanh', description: 'Chanh tươi', price: 15000), quantity: 2),
        ];
        _restaurantName = 'Phở Thìn Bờ Hồ';
        _restaurantEmoji = '🍜';
        _deliveryTime = '20-30 phút';
        _distance = '1.2 km';
        _deliveryFee = 15000;
      }
      _dataLoaded = true;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Xác nhận đơn hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== Restaurant ==========
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(_restaurantEmoji, style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_restaurantName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text('🕐 $_deliveryTime  •  📍 $_distance', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Delivery Address ==========
          _buildSectionTitle('📍 Địa chỉ giao hàng'),
          GestureDetector(
            onTap: () => _showAddressPicker(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Text('🏠', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(_selectedAddress, style: TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right, color: AppColors.text3, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ========== Items ==========
          _buildSectionTitle('🛒 Chi tiết đơn hàng (${_items.length} món)'),
          ..._items.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${c.quantity}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                if (c.item.description.isNotEmpty)
                  Text(c.item.description, style: TextStyle(fontSize: 11, color: AppColors.text3)),
              ])),
              Text('${_fmt.format(c.total)}đ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            ]),
          )),
          const SizedBox(height: 16),

          // ========== Promo Code ==========
          _buildSectionTitle('🎟️ Mã giảm giá'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _promoCtrl,
                style: TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(hintText: 'Nhập mã...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              )),
              GestureDetector(
                onTap: () {
                  if (_promoCtrl.text.isNotEmpty) {
                    setState(() => _promoApplied = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Áp dụng mã giảm 20.000đ'), backgroundColor: AppColors.green),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: _promoApplied ? AppColors.green : AppColors.blue, borderRadius: BorderRadius.circular(10)),
                  child: Text(_promoApplied ? '✓ Đã áp dụng' : 'Áp dụng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Payment Method ==========
          _buildSectionTitle('💳 Thanh toán'),
          ..._payments.map((p) => GestureDetector(
            onTap: () => setState(() => _selectedPayment = p['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedPayment == p['id'] ? AppColors.blueBg : AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedPayment == p['id'] ? AppColors.blue.withValues(alpha: 0.4) : AppColors.border),
              ),
              child: Row(children: [
                Text(p['emoji'] as String, style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(p['subtitle'] as String, style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ])),
                if (_selectedPayment == p['id'])
                  Icon(Icons.check_circle, color: AppColors.blue, size: 22),
              ]),
            ),
          )),
          const SizedBox(height: 16),

          // ========== Note ==========
          _buildSectionTitle('📝 Ghi chú'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(hintText: 'VD: Ít hành, thêm ớt, gọi khi đến...', border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
            ),
          ),
          const SizedBox(height: 20),

          // ========== Summary ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _buildSummaryRow('Tạm tính', '${_fmt.format(_subtotal)}đ'),
              _buildSummaryRow('Phí giao hàng', '${_fmt.format(_deliveryFee)}đ'),
              if (_discount > 0) _buildSummaryRow('Giảm giá', '-${_fmt.format(_discount)}đ', isDiscount: true),
              const Divider(color: AppColors.border, height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tổng cộng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                Text('${_fmt.format(_total)}đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.orange)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ========== Confirm Button ==========
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/order-tracking', arguments: {
              'cart': _items,
              'restaurantName': _restaurantName,
              'restaurantEmoji': _restaurantEmoji,
              'deliveryFee': _deliveryFee,
              'discount': _discount,
              'subtotal': _subtotal,
              'total': _total,
              'paymentMethod': _payments.firstWhere((p) => p['id'] == _selectedPayment)['name'],
              'address': _selectedAddress,
              'note': _noteCtrl.text,
            }),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.green, Color(0xFF2ECC71)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Center(child: Text('Xác nhận đặt hàng — ${_fmt.format(_total)}đ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.text2)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDiscount ? AppColors.green : AppColors.text)),
      ]),
    );
  }

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Chọn địa chỉ giao', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 16),
          ..._addresses.map((a) => GestureDetector(
            onTap: () {
              setState(() => _selectedAddress = '${a['label']} — ${a['address']}');
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Text(a['emoji'] as String, style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['label'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(a['address'] as String, style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ])),
                Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
              ]),
            ),
          )),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}
