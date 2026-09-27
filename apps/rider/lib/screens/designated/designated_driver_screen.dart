import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';

class DesignatedDriverScreen extends StatefulWidget {
  const DesignatedDriverScreen({super.key});

  @override
  State<DesignatedDriverScreen> createState() => _DesignatedDriverScreenState();
}

class _DesignatedDriverScreenState extends State<DesignatedDriverScreen> {
  String _vehicleType = 'Ô tô'; // 'Ô tô' | 'Xe máy'
  DesignatedDriverMode _mode = DesignatedDriverMode.solo;
  
  final _modelCtrl = TextEditingController(text: 'Mazda 3 (Sedan)');
  final _plateCtrl = TextEditingController(text: '51K-888.99');
  final _colorCtrl = TextEditingController(text: 'Đỏ pha lê (Soul Red)');
  final _pickupCtrl = TextEditingController(text: 'Quán Nhậu Lúa Mạch, 128 Nguyễn Trãi, Q.1');
  final _parkingCtrl = TextEditingController(text: 'Bãi giữ xe trước quán, có nhân viên giữ chìa');
  final _dropoffCtrl = TextEditingController(text: 'Chung cư Vinhomes Central Park, Bình Thạnh');
  
  String _paymentMethod = 'Ví Xebuonho';
  final double _distanceKm = 6.8;

  bool get _isNightTime {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 6;
  }

  int get _baseFare => _vehicleType == 'Ô tô' ? 60000 : 35000;
  int get _kmFare => (_distanceKm * (_vehicleType == 'Ô tô' ? 18000 : 10000)).toInt();
  int get _nightSurcharge => _isNightTime ? ((_baseFare + _kmFare) * 0.3).toInt() : 0;
  int get _shadowDriverFee => _mode == DesignatedDriverMode.duo ? 80000 : 0;
  int get _totalFare => _baseFare + _kmFare + _nightSurcharge + _shadowDriverFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Row(
          children: [
            Text('🚙', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Lái xe hộ (Bạn say tôi lái)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.text)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSafetyBanner(),
            const SizedBox(height: 16),
            _buildVehicleTypeSelector(),
            const SizedBox(height: 16),
            _buildModeSelector(),
            const SizedBox(height: 16),
            _buildVehicleInfoCard(),
            const SizedBox(height: 16),
            _buildLocationCard(),
            const SizedBox(height: 16),
            _buildInspectionGuaranteeCard(),
            const SizedBox(height: 16),
            _buildFareBreakdownCard(),
            const SizedBox(height: 16),
            _buildPaymentMethodCard(),
            const SizedBox(height: 24),
            _buildBookDriverButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.green.withValues(alpha: 0.25),
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Text('🛡️', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đã uống rượu bia — Không lái xe!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.green)),
                SizedBox(height: 2),
                Text(
                  'Tài xế chuyên nghiệp có GPLX B2/C sẽ lái xe của bạn đưa bạn và xe về nhà an toàn tuyệt đối.',
                  style: TextStyle(fontSize: 12, color: AppColors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
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
          const Text('Chọn loại phương tiện của bạn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption('Ô tô', '🚗', 'Xe 4 - 7 chỗ'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption('Xe máy', '🛵', 'Tay ga / Xe số'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String type, String emoji, String subtitle) {
    final isSelected = _vehicleType == type;
    return GestureDetector(
      onTap: () => setState(() => _vehicleType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blueBg : AppColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.blue : AppColors.border, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(type, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? AppColors.blue : AppColors.text)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
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
              Text('⚙️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Hình thức tài xế di chuyển', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          _buildModeRadio(
            DesignatedDriverMode.solo,
            'Solo (Tài xế đi xe gập)',
            'Tài xế đi xe scooter/xe đạp điện gấp, bỏ vào cốp ô tô. Tiết kiệm chi phí tối đa.',
            '🛴',
            'Tiết kiệm',
          ),
          const SizedBox(height: 10),
          _buildModeRadio(
            DesignatedDriverMode.duo,
            'Duo (Đội hình 2 tài xế - Shadow Driver)',
            '1 tài xế lái xe của bạn, 1 tài xế đi xe máy chạy sau theo sát và đón đồng đội về.',
            '👥',
            '+80.000đ',
          ),
        ],
      ),
    );
  }

  Widget _buildModeRadio(DesignatedDriverMode mode, String title, String desc, String emoji, String badge) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blueBg : AppColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.blue : AppColors.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard() {
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
              Text('🚘', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Thông tin xe cần lái hộ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField('Dòng xe & Hãng', _modelCtrl, 'Ví dụ: Mazda 3, Vios, Mercedes...'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildInputField('Biển số xe', _plateCtrl, '51K-888.99'),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _buildInputField('Màu xe', _colorCtrl, 'Đỏ, Đen, Trắng...'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInputField('Vị trí đỗ xe hiện tại', _parkingCtrl, 'Hầm B2, trước quán nhậu, bãi giữ xe...'),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
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

  Widget _buildLocationCard() {
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
              Text('🗺️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Lộ trình di chuyển', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField('Điểm đón (Nơi đỗ xe của bạn)', _pickupCtrl, 'Nhập địa chỉ đón...'),
          const SizedBox(height: 10),
          _buildInputField('Điểm trả (Nhà / Nơi gửi xe của bạn)', _dropoffCtrl, 'Nhập địa chỉ điểm đến...'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Ước tính lộ trình: $_distanceKm km', style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionGuaranteeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Text('📸', style: TextStyle(fontSize: 26)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quy trình Vehicle Inspection bắt buộc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.blue)),
                SizedBox(height: 2),
                Text(
                  'Tài xế sẽ chụp ảnh 4 góc xe, ghi nhận km đồng hồ và vết trầy xước có sẵn để bạn duyệt trước khi lái, bảo đảm an toàn quyền lợi đôi bên.',
                  style: TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareBreakdownCard() {
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
          const Text('Bảng giá cước lái xe hộ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 12),
          _buildPriceRow('Cước mở cuốc', _formatVND(_baseFare)),
          const SizedBox(height: 6),
          _buildPriceRow('Cước quãng đường ($_distanceKm km)', _formatVND(_kmFare)),
          if (_nightSurcharge > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Phụ thu đêm khuya (22h - 6h: +30%)', _formatVND(_nightSurcharge)),
          ],
          if (_shadowDriverFee > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Phí tài xế phụ (Shadow Driver)', _formatVND(_shadowDriverFee)),
          ],
          const Divider(color: AppColors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng cước chuyến đi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                  Text('Đã bao gồm bảo hiểm hành trình', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                ],
              ),
              Text(_formatVND(_totalFare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.green)),
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
      {'name': 'Tiền mặt', 'emoji': '💵'},
      {'name': 'SePay VietQR', 'emoji': '📲'},
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
          const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
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

  Widget _buildBookDriverButton() {
    return GestureDetector(
      onTap: _submitOrder,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.green, Color(0xFF0D9488)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🚙', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              'Tìm tài xế lái xe hộ (${_formatVND(_totalFare)})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _submitOrder() {
    final order = DesignatedDriverOrder(
      id: 'DD-${DateTime.now().millisecondsSinceEpoch % 100000}',
      vehicleType: _vehicleType,
      vehicleModel: _modelCtrl.text.trim(),
      licensePlate: _plateCtrl.text.trim(),
      vehicleColor: _colorCtrl.text.trim(),
      pickupAddress: _pickupCtrl.text.trim(),
      dropoffAddress: _dropoffCtrl.text.trim(),
      parkingLocationNote: _parkingCtrl.text.trim(),
      mode: _mode,
      status: DesignatedDriverStatus.driverAssigned,
      createdAt: DateTime.now(),
      paymentMethod: _paymentMethod,
      distanceKm: _distanceKm,
      baseFare: _baseFare,
      kmFare: _kmFare,
      nightSurcharge: _nightSurcharge,
      shadowDriverFee: _shadowDriverFee,
      totalFare: _totalFare,
      driverName: 'Trần Hữu Thắng (GPLX Hạng C)',
      driverPhone: '0912 345 678',
      driverRating: '4.98',
      shadowDriverName: _mode == DesignatedDriverMode.duo ? 'Lê Quốc Hưng (Tài xế phụ)' : null,
      inspection: VehicleInspection(
        odometerKm: 42150,
        fuelLevel: '3/4 bình xăng',
        photoFront: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=400',
        photoBack: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=400',
        photoLeft: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=400',
        photoRight: 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=400',
        existingDamages: [
          'Vết trầy nhẹ 3cm vè bánh sau bên phụ',
          'Cản trước có vết cọ quẹt nhỏ',
        ],
        customerConfirmed: false,
        inspectedAt: DateTime.now(),
      ),
    );

    Navigator.pushNamed(context, '/designated-tracking', arguments: order);
  }

  String _formatVND(int amount) {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => '${m[1]}.')} đ';
  }
}
