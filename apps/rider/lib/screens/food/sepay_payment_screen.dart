import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/sepay_service.dart';
import 'package:intl/intl.dart';

class SepayPaymentScreen extends StatefulWidget {
  const SepayPaymentScreen({super.key});

  @override
  State<SepayPaymentScreen> createState() => _SepayPaymentScreenState();
}

class _SepayPaymentScreenState extends State<SepayPaymentScreen> {
  final _fmt = NumberFormat('#,###', 'vi_VN');
  late String _orderId;
  late int _amount;
  late String _restaurantName;
  late String _qrUrl;
  bool _dataLoaded = false;

  // Payment status
  bool _checking = false;
  bool _paid = false;
  int _countdown = 300; // 5 minutes
  Timer? _countdownTimer;
  Timer? _pollTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _amount = args['total'] ?? 0;
        _restaurantName = args['restaurantName'] ?? '';
        _orderId = args['orderId'] ?? SepayService.generateOrderId();
      } else {
        _amount = 183000;
        _restaurantName = 'Phở Thìn Bờ Hồ';
        _orderId = SepayService.generateOrderId();
      }

      // Generate QR
      _qrUrl = SepayService.generateQrUrl(
        bankName: AppBankAccounts.primary.bankCode,
        accountNumber: AppBankAccounts.primary.accountNumber,
        amount: _amount,
        description: _orderId,
      );

      _dataLoaded = true;
      _startCountdown();
      _startPolling();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _countdown > 0 && !_paid) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  void _startPolling() {
    // Poll every 5 seconds to check payment
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (_paid || !mounted) {
        t.cancel();
        return;
      }
      setState(() => _checking = true);
      final sepay = SepayService();
      final isPaid = await sepay.checkPayment(orderId: _orderId, expectedAmount: _amount);
      if (mounted) {
        setState(() {
          _checking = false;
          if (isPaid) {
            _paid = true;
            t.cancel();
            // Navigate to tracking after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/order-tracking', arguments:
                  ModalRoute.of(context)?.settings.arguments);
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _countdownText {
    final min = _countdown ~/ 60;
    final sec = _countdown % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('Thanh toán SePay', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== Status ==========
          if (_paid)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text('Thanh toán thành công!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.green)),
                const SizedBox(height: 4),
                Text('Đang chuyển đến theo dõi đơn...', style: TextStyle(fontSize: 13, color: AppColors.text3)),
              ]),
            )
          else ...[
            // ========== Amount ==========
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A73E8).withValues(alpha: 0.12), Color(0xFF6C5CE7).withValues(alpha: 0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF1A73E8).withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Text('Số tiền cần thanh toán', style: TextStyle(fontSize: 14, color: AppColors.text3)),
                const SizedBox(height: 4),
                Text('${_fmt.format(_amount)}đ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 4),
                Text(_restaurantName, style: TextStyle(fontSize: 13, color: AppColors.text3)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(8)),
                  child: Text('⏱ Còn $_countdownText', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange)),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ========== QR Code ==========
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Text('🏧', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('VietQR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A73E8))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Text('💎', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('SePay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6C5CE7))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // QR Image from SePay
                Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _qrUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)));
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Color(0xFFF5F5F5),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('📱', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text('Quét mã QR\ntrên app ngân hàng', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Quét mã QR bằng app ngân hàng', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ]),
            ),
            const SizedBox(height: 16),

            // ========== Bank Info ==========
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hoặc chuyển khoản thủ công', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 12),
                _buildInfoRow('🏦 Ngân hàng', AppBankAccounts.primary.bankName),
                _buildInfoRow('👤 Chủ TK', AppBankAccounts.primary.accountName),
                _buildCopyRow('💳 Số TK', AppBankAccounts.primary.accountNumber),
                _buildCopyRow('💰 Số tiền', '${_fmt.format(_amount)}đ', copyValue: _amount.toString()),
                _buildCopyRow('📝 Nội dung CK', _orderId),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Text('⚠️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Vui lòng nhập đúng nội dung chuyển khoản để hệ thống tự xác nhận', style: TextStyle(fontSize: 12, color: AppColors.orange))),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ========== Checking Status ==========
            if (_checking)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue)),
                  const SizedBox(width: 10),
                  Text('Đang kiểm tra thanh toán...', style: TextStyle(fontSize: 13, color: AppColors.blue)),
                ]),
              ),

            const SizedBox(height: 16),

            // ========== Actions ==========
            GestureDetector(
              onTap: () {
                setState(() => _paid = true);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    Navigator.pushReplacementNamed(context, '/order-tracking', arguments: args);
                  }
                });
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.green, Color(0xFF2ECC71)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('✅ Tôi đã thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.text3))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
      ]),
    );
  }

  Widget _buildCopyRow(String label, String value, {String? copyValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.text3))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: copyValue ?? value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ Đã sao chép'), duration: const Duration(seconds: 1), backgroundColor: AppColors.green),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.copy, size: 14, color: AppColors.text3),
          ),
        ),
      ]),
    );
  }
}
