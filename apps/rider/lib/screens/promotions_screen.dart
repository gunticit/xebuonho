import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class _Promo {
  final String emoji;
  final String title;
  final String desc;
  final String code;
  final String expiry;
  final Color color;
  final String? targetRoute;
  bool active;

  _Promo({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.code,
    required this.expiry,
    required this.color,
    required this.active,
    this.targetRoute,
  });
}

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final _codeCtrl = TextEditingController();

  late final List<_Promo> _active = [
    _Promo(emoji: '🎉', title: 'Giảm 30% chuyến xe máy', desc: 'Áp dụng cho chuyến dưới 5km', code: 'BIKE30', expiry: 'Còn 3 ngày', color: AppColors.green, active: true, targetRoute: '/search'),
    _Promo(emoji: '🍔', title: 'Free ship đồ ăn', desc: 'Đơn từ 50.000đ', code: 'FREESHIP', expiry: 'Còn 7 ngày', color: AppColors.orange, active: true, targetRoute: '/food'),
  ];

  late final List<_Promo> _discover = [
    _Promo(emoji: '🚗', title: 'Giảm 50k ô tô', desc: 'Chuyến đầu tiên trong tuần', code: 'CAR50K', expiry: 'Còn 14 ngày', color: AppColors.blue, active: false, targetRoute: '/search'),
    _Promo(emoji: '⭐', title: 'Thưởng 2x điểm', desc: 'Tích điểm gấp đôi mỗi chuyến', code: 'DOUBLE', expiry: 'Còn 30 ngày', color: AppColors.purple, active: false),
    _Promo(emoji: '🛒', title: 'Giảm 20% đi chợ hộ', desc: 'Đơn từ 100.000đ trở lên', code: 'MARKET20', expiry: 'Còn 5 ngày', color: AppColors.cyan, active: false),
  ];

  final _expired = [
    _Promo(emoji: '💤', title: 'Giảm 15% xe máy', desc: 'Đã hết hạn 01/03', code: 'OLD15', expiry: 'Hết hạn', color: AppColors.text3, active: false),
  ];

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _applyTypedCode() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final all = [..._active, ..._discover];
    final found = all.firstWhere(
      (p) => p.code == code,
      orElse: () => _Promo(emoji: '❓', title: '', desc: '', code: '', expiry: '', color: AppColors.red, active: false),
    );

    if (found.code.isEmpty) {
      _snack('❌ Mã không hợp lệ hoặc đã hết hạn', AppColors.red);
      return;
    }

    setState(() {
      if (!found.active) {
        found.active = true;
        if (_discover.contains(found)) {
          _discover.remove(found);
          _active.add(found);
        }
      }
    });
    _codeCtrl.clear();
    _snack('✅ Đã thêm "${found.title}"', AppColors.green);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onPromoTap(_Promo p) {
    if (p.expiry == 'Hết hạn') {
      _snack('Mã này đã hết hạn', AppColors.text3);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.text3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: p.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(p.expiry, style: TextStyle(fontSize: 13, color: p.color, fontWeight: FontWeight.w600)),
            ])),
          ]),
          const SizedBox(height: 16),
          Text(p.desc, style: TextStyle(fontSize: 14, color: AppColors.text2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Text('🎫', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(p.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2, color: AppColors.text))),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: p.code));
                  Navigator.pop(context);
                  _snack('📋 Đã sao chép "${p.code}"', AppColors.blue);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.copy, color: AppColors.blue, size: 16),
                    const SizedBox(width: 6),
                    Text('Sao chép', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          if (p.targetRoute != null)
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, p.targetRoute!);
              },
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [p.color, p.color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('Sử dụng ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Khuyến mãi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Promo code input
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(color: AppColors.text, letterSpacing: 1),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _applyTypedCode(),
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã khuyến mãi',
                      prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppColors.text3, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _applyTypedCode,
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Áp dụng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('💡 Thử mã: BIKE30 · FREESHIP · CAR50K', style: TextStyle(fontSize: 11, color: AppColors.text3)),
            const SizedBox(height: 24),

            if (_active.isNotEmpty) ...[
              const Text('Đang có hiệu lực', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
              const SizedBox(height: 12),
              ..._active.map(_buildPromo),
              const SizedBox(height: 24),
            ],

            if (_discover.isNotEmpty) ...[
              const Text('Khám phá', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
              const SizedBox(height: 12),
              ..._discover.map(_buildPromo),
              const SizedBox(height: 24),
            ],

            const Text('Đã hết hạn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text3)),
            const SizedBox(height: 12),
            ..._expired.map((p) => Opacity(opacity: 0.5, child: _buildPromo(p))),
          ],
        ),
      ),
    );
  }

  Widget _buildPromo(_Promo p) {
    return GestureDetector(
      onTap: () => _onPromoTap(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.active ? p.color.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(p.desc, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bg3, borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2, letterSpacing: 1)),
                      ),
                      const SizedBox(width: 8),
                      Text(p.expiry, style: TextStyle(fontSize: 11, color: p.color, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            if (p.active) const Icon(Icons.check_circle, color: AppColors.green, size: 20),
          ],
        ),
      ),
    );
  }
}
