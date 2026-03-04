import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';
import 'package:intl/intl.dart';

class ShareBillScreen extends StatefulWidget {
  const ShareBillScreen({super.key});

  @override
  State<ShareBillScreen> createState() => _ShareBillScreenState();
}

class _ShareBillScreenState extends State<ShareBillScreen> {
  final _fmt = NumberFormat('#,###', 'vi_VN');
  final _nameCtrl = TextEditingController();
  int _splitMode = 0; // 0=equal, 1=by-item, 2=custom

  // Order data from route arguments
  late int _totalAmount;
  late List<CartItem> _items;
  late String _restaurantName;
  bool _dataLoaded = false;

  final _members = <ShareBillMember>[
    ShareBillMember(name: 'Tôi (Bạn)', amount: 0),
  ];

  // For by-item mode: which member owns which item
  final _itemAssignment = <String, int>{}; // itemId -> memberIndex

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _items = List<CartItem>.from(args['cart'] ?? []);
        _restaurantName = args['restaurantName'] ?? 'Nhà hàng';
        _totalAmount = args['total'] ?? 0;
      } else {
        // Fallback
        _items = [
          CartItem(item: MenuItem(id: '1', name: 'Phở tái nạm', description: '', price: 55000), quantity: 2),
          CartItem(item: MenuItem(id: '3', name: 'Phở gà', description: '', price: 48000)),
          CartItem(item: MenuItem(id: '7', name: 'Nước chanh', description: '', price: 15000), quantity: 2),
        ];
        _restaurantName = 'Phở Thìn Bờ Hồ';
        _totalAmount = 183000;
      }
      _dataLoaded = true;
      _recalculate();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addMember(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _members.add(ShareBillMember(name: name.trim(), amount: 0));
      _nameCtrl.clear();
      _recalculate();
    });
  }

  void _removeMember(int index) {
    if (index == 0) return;
    setState(() {
      _members.removeAt(index);
      _recalculate();
    });
  }

  void _recalculate() {
    if (_members.isEmpty) return;

    if (_splitMode == 0) {
      // Equal split
      final perPerson = _totalAmount ~/ _members.length;
      final remainder = _totalAmount - (perPerson * _members.length);
      for (var i = 0; i < _members.length; i++) {
        _members[i].amount = perPerson + (i == 0 ? remainder : 0);
      }
    } else if (_splitMode == 1) {
      // By item
      for (var m in _members) {
        m.amount = 0;
      }
      // Calculate shared costs (delivery fee estimate)
      final sharedCost = _totalAmount - _items.fold(0, (s, c) => s + c.total);
      final sharedPerPerson = sharedCost > 0 ? sharedCost ~/ _members.length : 0;
      for (var m in _members) {
        m.amount += sharedPerPerson;
      }
      // Assign item costs
      for (var item in _items) {
        final assignedTo = _itemAssignment[item.item.id] ?? 0;
        if (assignedTo < _members.length) {
          _members[assignedTo].amount += item.total;
        }
      }
    }
    // Custom mode: don't auto-recalculate
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Chia bill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== Total ==========
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purple.withValues(alpha: 0.15), AppColors.blue.withValues(alpha: 0.1)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Text('🧾', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text('Tổng đơn hàng', style: TextStyle(fontSize: 14, color: AppColors.text3)),
              Text('${_fmt.format(_totalAmount)}đ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              Text('$_restaurantName  •  ${_items.length} món', style: TextStyle(fontSize: 13, color: AppColors.text3)),
            ]),
          ),
          const SizedBox(height: 20),

          // ========== Add Members ==========
          Text('👥 Thành viên (${_members.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(hintText: 'Tên người...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                onSubmitted: _addMember,
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addMember(_nameCtrl.text),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_add, color: Colors.white, size: 20),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Member chips
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(_members.length, (i) {
              final m = _members[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.blueBg : AppColors.bg2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: i == 0 ? AppColors.blue.withValues(alpha: 0.3) : AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(i == 0 ? '👤' : '🧑', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(m.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                  if (i > 0) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeMember(i),
                      child: Icon(Icons.close, size: 16, color: AppColors.text3),
                    ),
                  ],
                ]),
              );
            }),
          ),
          const SizedBox(height: 20),

          // ========== Split Mode ==========
          Text('📊 Cách chia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(children: [
            _buildModeTab(0, '➗ Chia đều'),
            const SizedBox(width: 8),
            _buildModeTab(1, '🍜 Theo món'),
            const SizedBox(width: 8),
            _buildModeTab(2, '✏️ Tùy chỉnh'),
          ]),
          const SizedBox(height: 20),

          // ========== By-item assignment ==========
          if (_splitMode == 1) ...[
            Text('Gán món cho người', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text3)),
            const SizedBox(height: 8),
            ..._items.map((item) {
              final assignedTo = _itemAssignment[item.item.id] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${item.quantity}x ${item.item.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text)),
                    Text('${_fmt.format(item.total)}đ', style: TextStyle(fontSize: 12, color: AppColors.orange)),
                  ])),
                  DropdownButton<int>(
                    value: assignedTo < _members.length ? assignedTo : 0,
                    dropdownColor: AppColors.bg2,
                    style: TextStyle(fontSize: 13, color: AppColors.text),
                    underline: const SizedBox(),
                    items: List.generate(_members.length, (i) => DropdownMenuItem(value: i, child: Text(_members[i].name, style: TextStyle(fontSize: 13, color: AppColors.text)))),
                    onChanged: (v) => setState(() {
                      _itemAssignment[item.item.id] = v!;
                      _recalculate();
                    }),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 12),
          ],

          // ========== Result Table ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text('Người', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text3))),
                Text('Số tiền', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text3)),
                const SizedBox(width: 50),
              ]),
              const Divider(color: AppColors.border, height: 16),
              ..._members.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Text(i == 0 ? '👤' : '🧑', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
                    if (_splitMode == 2)
                      SizedBox(
                        width: 90,
                        child: TextField(
                          style: TextStyle(fontSize: 14, color: AppColors.orange, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.only(bottom: 4), border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)), suffixText: 'đ'),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: '${m.amount}'),
                          onChanged: (v) {
                            _members[i].amount = int.tryParse(v) ?? 0;
                          },
                        ),
                      )
                    else
                      Text('${_fmt.format(m.amount)}đ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.orange)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => m.paid = !m.paid),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: m.paid ? AppColors.green : AppColors.bg3,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m.paid ? Icons.check : Icons.circle_outlined, size: 16, color: m.paid ? Colors.white : AppColors.text3),
                      ),
                    ),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 20),

          // ========== Share Actions ==========
          Text('📤 Gửi yêu cầu thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildShareBtn('📋 Sao chép', AppColors.blue, () {
              final text = _generateShareText();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ Đã sao chép nội dung chia bill'), backgroundColor: AppColors.green),
              );
            })),
            const SizedBox(width: 8),
            Expanded(child: _buildShareBtn('💬 Zalo', Color(0xFF0068FF), () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('📤 Đang mở Zalo...'), backgroundColor: AppColors.blue),
              );
            })),
            const SizedBox(width: 8),
            Expanded(child: _buildShareBtn('📱 SMS', AppColors.green, () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('📤 Đang gửi SMS...'), backgroundColor: AppColors.green),
              );
            })),
          ]),
          const SizedBox(height: 16),

          // ========== Payment Link ==========
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: 'https://xebuonho.vn/pay/XBN240304001'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🔗 Đã sao chép link thanh toán'), backgroundColor: AppColors.green),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Text('🔗', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Link thanh toán', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text('xebuonho.vn/pay/XBN240304001', style: TextStyle(fontSize: 12, color: AppColors.green)),
                ])),
                Icon(Icons.copy, color: AppColors.green, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildModeTab(int mode, String label) {
    final isSelected = _splitMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _splitMode = mode;
          _recalculate();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.purple.withValues(alpha: 0.15) : AppColors.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.purple.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Center(child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.purple : AppColors.text3,
          ))),
        ),
      ),
    );
  }

  Widget _buildShareBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
      ),
    );
  }

  String _generateShareText() {
    final lines = <String>[
      '🧾 Chia bill — $_restaurantName',
      'Tổng: ${_fmt.format(_totalAmount)}đ',
      '',
      ...List.generate(_members.length, (i) {
        final m = _members[i];
        return '${i == 0 ? "👤" : "🧑"} ${m.name}: ${_fmt.format(m.amount)}đ ${m.paid ? "✅" : "⏳"}';
      }),
      '',
      '💳 Thanh toán: xebuonho.vn/pay/XBN240304001',
    ];
    return lines.join('\n');
  }
}
