import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _fmt = NumberFormat('#,###', 'vi_VN');
  int _currentStep = 0;
  Timer? _timer;

  // Order data from checkout
  late List<CartItem> _items;
  late String _restaurantName;
  late String _restaurantEmoji;
  late int _subtotal;
  late int _deliveryFee;
  late int _discount;
  late int _total;
  late String _paymentMethod;
  late String _address;
  String _note = '';
  bool _dataLoaded = false;

  bool _ratingShown = false;
  int? _userRating;

  final _steps = <Map<String, dynamic>>[
    {'status': OrderStatus.placed, 'time': '', 'done': true},
    {'status': OrderStatus.confirmed, 'time': '', 'done': false},
    {'status': OrderStatus.preparing, 'time': '', 'done': false},
    {'status': OrderStatus.pickedUp, 'time': '', 'done': false},
    {'status': OrderStatus.delivering, 'time': '', 'done': false},
    {'status': OrderStatus.delivered, 'time': '', 'done': false},
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
        _subtotal = args['subtotal'] ?? 0;
        _deliveryFee = args['deliveryFee'] ?? 15000;
        _discount = args['discount'] ?? 0;
        _total = args['total'] ?? 0;
        _paymentMethod = args['paymentMethod'] ?? 'Ví Xebuonho';
        _address = args['address'] ?? '';
        _note = args['note'] ?? '';
      } else {
        // Fallback
        _items = [
          CartItem(item: MenuItem(id: '1', name: 'Phở tái nạm', description: '', price: 55000), quantity: 2),
          CartItem(item: MenuItem(id: '3', name: 'Phở gà', description: '', price: 48000)),
        ];
        _restaurantName = 'Phở Thìn Bờ Hồ';
        _restaurantEmoji = '🍜';
        _subtotal = 158000;
        _deliveryFee = 15000;
        _discount = 0;
        _total = 173000;
        _paymentMethod = 'Ví Xebuonho';
        _address = 'Nhà — 123 Nguyễn Huệ, Q.1';
      }
      _steps[0]['time'] = DateFormat('HH:mm').format(DateTime.now());
      _dataLoaded = true;
    }
  }

  @override
  void initState() {
    super.initState();
    // Simulate order progression
    _timer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
          _steps[_currentStep]['done'] = true;
          _steps[_currentStep]['time'] = DateFormat('HH:mm').format(DateTime.now());
        });
        if (_steps[_currentStep]['status'] == OrderStatus.delivered && !_ratingShown) {
          _ratingShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showRatingSheet();
          });
        }
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _orderArgs => {
    'cart': _items,
    'restaurantName': _restaurantName,
    'restaurantEmoji': _restaurantEmoji,
    'subtotal': _subtotal,
    'deliveryFee': _deliveryFee,
    'discount': _discount,
    'total': _total,
    'paymentMethod': _paymentMethod,
    'address': _address,
    'note': _note,
    'rating': _userRating,
    'status': _steps[_currentStep]['status'] as OrderStatus,
  };

  bool get _isDelivered => _steps[_currentStep]['status'] == OrderStatus.delivered;

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final currentStatus = _steps[_currentStep]['status'] as OrderStatus;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Theo dõi đơn hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(icon: Icon(Icons.help_outline, color: AppColors.text3), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== Status Banner ==========
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.green.withValues(alpha: 0.15), AppColors.blue.withValues(alpha: 0.08)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text(currentStatus.emoji, style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              Text(currentStatus.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(_getStatusMessage(), style: TextStyle(fontSize: 14, color: AppColors.text3)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(10)),
                child: Text('⏱ Dự kiến 20-30 phút', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ========== Timeline ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: List.generate(_steps.length, (i) => _buildTimelineStep(i)),
            ),
          ),
          const SizedBox(height: 16),

          // ========== Driver Info (from step pickedUp) ==========
          if (_currentStep >= 3) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('T', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Trần Văn Tài', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    Row(children: [
                      Text('⭐ 4.9', style: TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w600)),
                      Text('  •  59F1-12345  •  Honda Wave', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                    ]),
                  ])),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _buildActionBtn('📞 Gọi', AppColors.green, () {})),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionBtn('💬 Chat', AppColors.blue, () => Navigator.pushNamed(context, '/chat'))),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ========== Order Summary ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(_restaurantEmoji, style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(_restaurantName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              ]),
              const SizedBox(height: 10),
              ..._items.map((c) => _buildOrderItem('${c.quantity}x ${c.item.name}', c.total)),
              Divider(color: AppColors.border, height: 20),
              _buildPriceRow('Tạm tính', _subtotal),
              _buildPriceRow('Phí giao', _deliveryFee),
              if (_discount > 0) _buildPriceRow('Giảm giá', -_discount, isGreen: true),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tổng cộng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                Text('${_fmt.format(_total)}đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.orange)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // ========== Delivered: View detail ==========
          if (_isDelivered) ...[
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/order-detail', arguments: _orderArgs),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.green.withValues(alpha: 0.2), AppColors.blue.withValues(alpha: 0.1)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Text('📋', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Xem chi tiết đơn hàng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    Text('Hoá đơn, đánh giá, đặt lại', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                  ])),
                  Icon(Icons.chevron_right, color: AppColors.green, size: 22),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ========== Share Bill Button ==========
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/share-bill', arguments: _orderArgs),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.purple.withValues(alpha: 0.15), AppColors.blue.withValues(alpha: 0.1)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Text('🧾', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Chia bill với bạn bè', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                  Text('Chia đều, theo món, hoặc tùy chỉnh', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                ])),
                Icon(Icons.chevron_right, color: AppColors.purple, size: 22),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (_currentStep) {
      case 0: return 'Đơn hàng đã được gửi đến nhà hàng';
      case 1: return 'Nhà hàng đã nhận đơn của bạn';
      case 2: return 'Đầu bếp đang chuẩn bị món ăn';
      case 3: return 'Tài xế đã lấy đơn hàng';
      case 4: return 'Đơn hàng đang trên đường đến bạn';
      case 5: return 'Đơn hàng đã được giao thành công 🎉';
      default: return '';
    }
  }

  void _showRatingSheet() {
    int selected = 5;
    final tags = <String>{};
    final allTags = ['Đúng giờ', 'Món ngon', 'Đóng gói tốt', 'Tài xế lịch sự', 'Giao nhanh'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.text3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text('Đơn hàng đã được giao!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            Text('Đánh giá trải nghiệm của bạn', style: TextStyle(fontSize: 13, color: AppColors.text3)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
              final filled = i < selected;
              return GestureDetector(
                onTap: () => setSheet(() => selected = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.star, size: 36, color: filled ? AppColors.orange : AppColors.bg3),
                ),
              );
            })),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: allTags.map((t) {
                final on = tags.contains(t);
                return GestureDetector(
                  onTap: () => setSheet(() => on ? tags.remove(t) : tags.add(t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: on ? AppColors.orangeBg : AppColors.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? AppColors.orange : AppColors.border),
                    ),
                    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? AppColors.orange : AppColors.text2)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() => _userRating = selected);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Cảm ơn bạn đã đánh giá ${selected} sao!'), backgroundColor: AppColors.green),
                );
              },
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.orange, Color(0xFFE67E22)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('Gửi đánh giá', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Để sau', style: TextStyle(color: AppColors.text3)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(int index) {
    final step = _steps[index];
    final status = step['status'] as OrderStatus;
    final isDone = step['done'] as bool;
    final isCurrent = index == _currentStep;
    final isLast = index == _steps.length - 1;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 30,
        child: Column(children: [
          Container(
            width: isCurrent ? 24 : 18,
            height: isCurrent ? 24 : 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppColors.green : AppColors.bg3,
              border: isCurrent ? Border.all(color: AppColors.green, width: 3) : null,
              boxShadow: isCurrent ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 8)] : null,
            ),
            child: isDone ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          if (!isLast)
            Container(width: 2, height: 36, color: isDone ? AppColors.green.withValues(alpha: 0.5) : AppColors.bg3),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
          child: Row(children: [
            Text(status.emoji, style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(status.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isDone ? AppColors.text : AppColors.text3,
              ),
            )),
            if (isDone && (step['time'] as String).isNotEmpty)
              Text(step['time'] as String, style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
      ),
    );
  }

  Widget _buildOrderItem(String label, int price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.text2)),
        Text('${_fmt.format(price)}đ', style: TextStyle(fontSize: 13, color: AppColors.text)),
      ]),
    );
  }

  Widget _buildPriceRow(String label, int amount, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.text3)),
        Text('${amount < 0 ? '-' : ''}${_fmt.format(amount.abs())}đ',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isGreen ? AppColors.green : AppColors.text2)),
      ]),
    );
  }
}
