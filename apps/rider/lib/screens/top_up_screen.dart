import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'package:intl/intl.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _fmt = NumberFormat('#,###', 'vi_VN');
  int _selectedAmount = 0;
  String _selectedMethod = 'momo';
  final _customCtrl = TextEditingController();

  final _amounts = [50000, 100000, 200000, 500000, 1000000, 2000000];

  final _methods = [
    {'id': 'momo', 'name': 'MoMo', 'emoji': '🟣', 'desc': 'Ví MoMo'},
    {'id': 'zalopay', 'name': 'ZaloPay', 'emoji': '🔵', 'desc': 'Ví ZaloPay'},
    {'id': 'bank', 'name': 'Ngân hàng', 'emoji': '🏦', 'desc': 'Chuyển khoản'},
    {'id': 'card', 'name': 'Thẻ Visa/MC', 'emoji': '💳', 'desc': 'Thẻ quốc tế'},
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Nạp tiền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current balance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.green.withValues(alpha: 0.15), AppColors.blue.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Số dư hiện tại', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                        const SizedBox(height: 4),
                        Text('250.000đ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.green)),
                      ],
                    ),
                  ),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('💰', style: TextStyle(fontSize: 24))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount selection
            Text('Chọn số tiền', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: _amounts.map((amt) {
                final isSelected = _selectedAmount == amt;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedAmount = amt;
                    _customCtrl.clear();
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.blueBg : AppColors.bg2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border, width: isSelected ? 2 : 1),
                    ),
                    child: Center(
                      child: Text(
                        '${_fmt.format(amt)}đ',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.blue : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Custom amount
            TextField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
              onChanged: (v) {
                final n = int.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                setState(() => _selectedAmount = n ?? 0);
              },
              decoration: InputDecoration(
                hintText: 'Hoặc nhập số tiền khác',
                prefixIcon: Icon(Icons.edit, color: AppColors.text3, size: 20),
                suffixText: 'đ',
                suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text2),
              ),
            ),

            const SizedBox(height: 24),

            // Payment method
            Text('Nguồn tiền', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),

            ..._methods.map((m) {
              final isSelected = _selectedMethod == m['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedMethod = m['id']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.blueBg : AppColors.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.blue : AppColors.border, width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(m['emoji']!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['name']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                            Text(m['desc']!, style: TextStyle(fontSize: 12, color: AppColors.text3)),
                          ],
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: AppColors.blue, size: 22),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Promo code
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text('🎁', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Mã khuyến mãi nạp tiền', style: TextStyle(fontSize: 14, color: AppColors.text2))),
                  Text('Nhập mã', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Summary
            if (_selectedAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildRow('Số tiền nạp', '${_fmt.format(_selectedAmount)}đ'),
                    _buildRow('Phí giao dịch', 'Miễn phí', isGreen: true),
                    Divider(color: AppColors.border, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tổng thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                        Text('${_fmt.format(_selectedAmount)}đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _selectedAmount > 0 ? () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.bg2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✅', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('Nạp tiền thành công!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 4),
                          Text('+${_fmt.format(_selectedAmount)}đ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green)),
                          const SizedBox(height: 4),
                          Text('Số dư mới: ${_fmt.format(250000 + _selectedAmount)}đ', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                        ],
                      ),
                      actions: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  disabledBackgroundColor: AppColors.bg3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _selectedAmount > 0 ? 'Nạp ${_fmt.format(_selectedAmount)}đ' : 'Chọn số tiền để nạp',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _selectedAmount > 0 ? Colors.white : AppColors.text3),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.text2)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isGreen ? AppColors.green : AppColors.text)),
        ],
      ),
    );
  }
}
