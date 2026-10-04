import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/active_order_provider.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _senderNameCtrl = TextEditingController(text: 'Nguyễn Văn Minh');
  final _senderPhoneCtrl = TextEditingController(text: '0901 234 567');
  final _senderAddrCtrl = TextEditingController(text: 'Tòa nhà Bitexco, 2 Hải Triều, Q.1');
  final _senderNoteCtrl = TextEditingController(text: 'Lấy hàng tại sảnh lễ tân');

  final _receiverNameCtrl = TextEditingController(text: 'Trần Thị Thu Hà');
  final _receiverPhoneCtrl = TextEditingController(text: '0988 765 432');
  final _receiverAddrCtrl = TextEditingController(text: 'Chung cư Masteri Thảo Điền, TP. Thủ Đức');
  final _receiverNoteCtrl = TextEditingController(text: 'Gọi trước khi đến, gửi bảo vệ tháp T2');

  String _packageType = '📄 Tài liệu';
  String _packageWeight = '< 5 kg';
  String _serviceSpeed = 'speedy'; // 'speedy' | 'standard'
  bool _handToHand = true;
  bool _needCod = false;
  final _codAmountCtrl = TextEditingController(text: '250000');
  String _paymentMethod = 'Ví Xebuonho';

  final List<Map<String, String>> _packageTypes = [
    {'name': '📄 Tài liệu', 'desc': 'Hợp đồng, giấy tờ'},
    {'name': '👕 Quần áo', 'desc': 'Thời trang, phụ kiện'},
    {'name': '📱 Điện tử', 'desc': 'Điện thoại, linh kiện'},
    {'name': '🍜 Thực phẩm', 'desc': 'Đồ ăn khô, bánh ngọt'},
    {'name': '🍷 Dễ vỡ', 'desc': 'Rượu vang, mỹ phẩm'},
  ];

  int get _baseFee => _serviceSpeed == 'speedy' ? 32000 : 20000;
  int get _weightFee => _packageWeight == '< 5 kg' ? 0 : (_packageWeight == '5 - 10 kg' ? 10000 : 25000);
  int get _handToHandFee => _handToHand ? 5000 : 0;
  int get _totalDeliveryFee => _baseFee + _weightFee + _handToHandFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Row(
          children: [
            Text('📦', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Giao hàng hỏa tốc (Express)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.text)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSenderCard(),
            const SizedBox(height: 14),
            _buildReceiverCard(),
            const SizedBox(height: 14),
            _buildPackageDetailsCard(),
            const SizedBox(height: 14),
            _buildDeliverySpeedCard(),
            const SizedBox(height: 14),
            _buildExtraServicesCard(),
            const SizedBox(height: 14),
            _buildPricingCard(),
            const SizedBox(height: 14),
            _buildPaymentMethodCard(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📤', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Thông tin người gửi (Điểm lấy hàng)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 5, child: _buildTextField('Tên người gửi', _senderNameCtrl)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _buildTextField('Số điện thoại', _senderPhoneCtrl, isPhone: true)),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField('Địa chỉ lấy hàng *', _senderAddrCtrl),
          const SizedBox(height: 10),
          _buildTextField('Ghi chú lấy hàng', _senderNoteCtrl, hint: 'Số phòng, lầu, nhân viên liên hệ...'),
        ],
      ),
    );
  }

  Widget _buildReceiverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📥', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Thông tin người nhận (Điểm giao hàng)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 5, child: _buildTextField('Tên người nhận', _receiverNameCtrl)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _buildTextField('Số điện thoại', _receiverPhoneCtrl, isPhone: true)),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField('Địa chỉ giao hàng *', _receiverAddrCtrl),
          const SizedBox(height: 10),
          _buildTextField('Ghi chú giao hàng', _receiverNoteCtrl, hint: 'Gửi lễ tân, gọi trước khi đến...'),
        ],
      ),
    );
  }

  Widget _buildPackageDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📋', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Chi tiết gói hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Loại hàng hóa', style: TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _packageTypes.map((item) {
                final isSelected = _packageType == item['name'];
                return GestureDetector(
                  onTap: () => setState(() => _packageType = item['name']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.blueBg : AppColors.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
                    ),
                    child: Text(
                      item['name']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.blue : AppColors.text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Khối lượng gói hàng', style: TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ['< 5 kg', '5 - 10 kg', '10 - 20 kg'].map((w) {
              final isSelected = _packageWeight == w;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _packageWeight = w),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.blueBg : AppColors.bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? AppColors.blue : AppColors.text2),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySpeedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⚡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Tốc độ giao hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          _buildSpeedOption(
            id: 'speedy',
            emoji: '🚀',
            title: 'Giao Siêu Tốc (30 - 45 phút)',
            desc: 'Shipper nhận hàng và giao ngay lập tức, ưu tiên cao nhất',
            price: '32.000đ',
            badge: 'Khuyên dùng',
          ),
          const SizedBox(height: 10),
          _buildSpeedOption(
            id: 'standard',
            emoji: '⏱️',
            title: 'Giao Tiêu Chuẩn (2 - 3 giờ)',
            desc: 'Giao trong buổi, kết hợp lộ trình tiết kiệm chi phí',
            price: '20.000đ',
            badge: 'Tiết kiệm',
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedOption({
    required String id,
    required String emoji,
    required String title,
    required String desc,
    required String price,
    required String badge,
  }) {
    final isSelected = _serviceSpeed == id;
    return GestureDetector(
      onTap: () => setState(() => _serviceSpeed = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blueBg : AppColors.bg3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(4)),
                        child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                ],
              ),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.orange)),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraServicesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dịch vụ bổ sung', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _handToHand,
                activeColor: AppColors.blue,
                onChanged: (v) => setState(() => _handToHand = v ?? true),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giao tận tay (+5.000đ)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text('Shipper lên tận phòng/lầu trao tận tay người nhận', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _needCod,
                activeColor: AppColors.blue,
                onChanged: (v) => setState(() => _needCod = v ?? false),
              ),
              const Expanded(
                child: Text('Thu hộ tiền hàng (COD)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              ),
            ],
          ),
          if (_needCod) ...[
            const SizedBox(height: 8),
            _buildTextField('Số tiền thu hộ COD (VND)', _codAmountCtrl, isPhone: true),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiết cước phí giao hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 12),
          _buildPriceRow('Cước vận chuyển cơ bản', _formatVND(_baseFee)),
          if (_weightFee > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Phụ phí khối lượng ($_packageWeight)', _formatVND(_weightFee)),
          ],
          if (_handToHandFee > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Phí dịch vụ giao tận tay', _formatVND(_handToHandFee)),
          ],
          const Divider(color: AppColors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng cước giao hàng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                  Text('Bảo hiểm bồi hoàn 100% giá trị gói hàng', style: TextStyle(fontSize: 11, color: AppColors.green)),
                ],
              ),
              Text(_formatVND(_totalDeliveryFee), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
      ],
    );
  }

  Widget _buildPaymentMethodCard() {
    final methods = [
      {'name': 'Ví Xebuonho', 'emoji': '💳'},
      {'name': 'Người gửi trả', 'emoji': '💵'},
      {'name': 'Người nhận trả', 'emoji': '📦'},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Người thanh toán cước', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(
            children: methods.map((m) {
              final isSelected = _paymentMethod == m['name'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m['name'] as String),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.blueBg : AppColors.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(m['emoji'] as String, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(m['name'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? AppColors.blue : AppColors.text), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitDeliveryOrder,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📦', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              'Xác nhận đặt giao hàng (${_formatVND(_totalDeliveryFee)})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _submitDeliveryOrder() {
    final orderId = 'EXPRESS-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final entry = ActiveOrderEntry(
      id: orderId,
      type: ActiveOrderType.delivery,
      title: 'Giao hàng: $_packageType',
      subtitle: 'Tới: ${_receiverAddrCtrl.text}',
      statusText: 'Đang điều phối shipper đến lấy hàng',
      emoji: '📦',
      routePath: '/activities',
      etaMinutes: _serviceSpeed == 'speedy' ? 35 : 120,
      progress: 0.25,
    );

    context.read<ActiveOrderProvider>().addOrder(entry);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 50)),
              const SizedBox(height: 12),
              const Text('Đặt giao hàng thành công!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
              const SizedBox(height: 6),
              Text(
                'Mã đơn hàng #$orderId.\nShipper đang đến địa chỉ người gửi để nhận bưu kiện.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.text2),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Xem trên Trang chủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.text3, fontSize: 12),
            filled: true,
            fillColor: AppColors.bg3,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  String _formatVND(int amount) {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => '${m[1]}.')} đ';
  }
}
