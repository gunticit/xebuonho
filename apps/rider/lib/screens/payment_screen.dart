import 'package:flutter/material.dart';
import '../config/theme.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selected = 'cash';

  final _methods = [
    {'id': 'cash', 'name': 'Tiền mặt', 'icon': '💵', 'desc': 'Thanh toán khi đến nơi', 'color': 'green'},
    {'id': 'momo', 'name': 'MoMo', 'icon': '🟣', 'desc': '**** 4567', 'color': 'purple'},
    {'id': 'zalopay', 'name': 'ZaloPay', 'icon': '🔵', 'desc': '**** 8901', 'color': 'blue'},
    {'id': 'vnpay', 'name': 'VNPay', 'icon': '🔴', 'desc': 'Chưa liên kết', 'color': 'red'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Thanh toán', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.2), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Số dư ví', style: TextStyle(fontSize: 13, color: AppColors.text3)),
                  const SizedBox(height: 4),
                  const Text('250.000đ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildWalletBtn('Nạp tiền', Icons.add_circle_outline, AppColors.green,
                        onTap: () => Navigator.pushNamed(context, '/top-up')),
                      const SizedBox(width: 12),
                      _buildWalletBtn('Rút tiền', Icons.arrow_circle_down, AppColors.orange),
                      const SizedBox(width: 12),
                      _buildWalletBtn('Lịch sử', Icons.receipt_long, AppColors.blue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment methods
            const Text('Phương thức thanh toán',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),

            ..._methods.map((m) => _buildMethod(m)),

            const SizedBox(height: 16),

            // Add method
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Thêm phương thức', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blue)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recent transactions
            const Text('Giao dịch gần đây',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 12),
            _buildTransaction('🚗 Xe máy - Q.1 → Q.7', '-35.000đ', '14:30 hôm nay', false),
            _buildTransaction('💰 Nạp tiền MoMo', '+200.000đ', '10:15 hôm qua', true),
            _buildTransaction('🍔 GrabFood - Phở 24', '-55.000đ', '08:00 hôm qua', false),
            _buildTransaction('🚙 Ô tô - Tân Sơn Nhất', '-120.000đ', '20/02', false),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletBtn(String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethod(Map<String, String> m) {
    final isSelected = _selected == m['id'];
    return GestureDetector(
      onTap: () => setState(() => _selected = m['id']!),
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
            Text(m['icon']!, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(m['desc']!, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.blue, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildTransaction(String title, String amount, String time, bool isCredit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text)),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
              ],
            ),
          ),
          Text(amount, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: isCredit ? AppColors.green : AppColors.red,
          )),
        ],
      ),
    );
  }
}
