import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';

class DesignatedTrackingScreen extends StatefulWidget {
  final DesignatedDriverOrder? order;

  const DesignatedTrackingScreen({super.key, this.order});

  @override
  State<DesignatedTrackingScreen> createState() => _DesignatedTrackingScreenState();
}

class _DesignatedTrackingScreenState extends State<DesignatedTrackingScreen> {
  late DesignatedDriverOrder _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order ?? _createMockOrder();
  }

  DesignatedDriverOrder _createMockOrder() {
    return DesignatedDriverOrder(
      id: 'DD-78219',
      vehicleType: 'Ô tô',
      vehicleModel: 'Mazda 3 (Sedan)',
      licensePlate: '51K-888.99',
      vehicleColor: 'Đỏ pha lê',
      pickupAddress: 'Quán Nhậu Lúa Mạch, 128 Nguyễn Trãi, Q.1',
      dropoffAddress: 'Chung cư Vinhomes Central Park, Bình Thạnh',
      parkingLocationNote: 'Bãi xe trước quán, chìa khóa nhân viên giữ',
      mode: DesignatedDriverMode.solo,
      status: DesignatedDriverStatus.inspecting,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      paymentMethod: 'Ví Xebuonho',
      distanceKm: 6.8,
      baseFare: 60000,
      kmFare: 122400,
      nightSurcharge: 54720,
      totalFare: 237120,
      driverName: 'Trần Hữu Thắng (GPLX Hạng C)',
      driverPhone: '0912 345 678',
      driverRating: '4.98',
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
  }

  void _advanceState() {
    setState(() {
      switch (_order.status) {
        case DesignatedDriverStatus.created:
          _order.status = DesignatedDriverStatus.driverAssigned;
          break;
        case DesignatedDriverStatus.driverAssigned:
          _order.status = DesignatedDriverStatus.driverArriving;
          break;
        case DesignatedDriverStatus.driverArriving:
          _order.status = DesignatedDriverStatus.arrived;
          break;
        case DesignatedDriverStatus.arrived:
          _order.status = DesignatedDriverStatus.inspecting;
          _showInspectionModal();
          break;
        case DesignatedDriverStatus.inspecting:
          _order.status = DesignatedDriverStatus.inspectionConfirmed;
          break;
        case DesignatedDriverStatus.inspectionConfirmed:
          _order.status = DesignatedDriverStatus.driving;
          break;
        case DesignatedDriverStatus.driving:
          _order.status = DesignatedDriverStatus.arrivedDestination;
          break;
        case DesignatedDriverStatus.arrivedDestination:
          _order.status = DesignatedDriverStatus.completed;
          _showCompletedDialog();
          break;
        case DesignatedDriverStatus.completed:
        case DesignatedDriverStatus.cancelled:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuốc lái xe hộ #${_order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
            Text('${_order.vehicleModel} • ${_order.licensePlate}', style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: AppColors.blue),
            onPressed: () => Navigator.pushNamed(context, '/support'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusHeaderCard(),
            const SizedBox(height: 16),
            _buildDriverProfileCard(),
            const SizedBox(height: 16),
            _buildVehicleDetailCard(),
            const SizedBox(height: 16),
            _buildInspectionCard(),
            const SizedBox(height: 16),
            _buildRouteCard(),
            const SizedBox(height: 16),
            _buildPricingCard(),
            const SizedBox(height: 24),
            _buildSimulationControls(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.green.withValues(alpha: 0.22),
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.greenBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(_order.status.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_order.status.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text(_getStatusDescription(), style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _getProgressValue(),
              backgroundColor: AppColors.bg3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription() {
    switch (_order.status) {
      case DesignatedDriverStatus.created:
        return 'Đang tìm kiếm tài xế có GPLX phù hợp gần bạn nhất...';
      case DesignatedDriverStatus.driverAssigned:
        return 'Tài xế ${_order.driverName} đã nhận cuốc và chuẩn bị khởi hành';
      case DesignatedDriverStatus.driverArriving:
        return 'Tài xế đang di chuyển tới điểm đỗ xe (${_order.mode == DesignatedDriverMode.solo ? "đi xe gập" : "có tài xế phụ đi kèm"})';
      case DesignatedDriverStatus.arrived:
        return 'Tài xế đã đến vị trí xe của bạn và chuẩn bị kiểm tra tình trạng';
      case DesignatedDriverStatus.inspecting:
        return 'Đang chụp ảnh 4 góc xe và kiểm tra km đồng hồ, trầy xước';
      case DesignatedDriverStatus.inspectionConfirmed:
        return 'Biên bản kiểm tra xe đã được duyệt. Tài xế bắt đầu lái';
      case DesignatedDriverStatus.driving:
        return 'Đang lái xe đưa bạn và phương tiện về nhà an toàn';
      case DesignatedDriverStatus.arrivedDestination:
        return 'Đã đến điểm trả! Tài xế hỗ trợ đưa xe vào bãi đỗ an toàn';
      case DesignatedDriverStatus.completed:
        return 'Đã bàn giao chìa khóa xe thành công. Chúc bạn nghỉ ngơi khỏe!';
      case DesignatedDriverStatus.cancelled:
        return 'Chuyến đi đã được hủy';
    }
  }

  double _getProgressValue() {
    switch (_order.status) {
      case DesignatedDriverStatus.created: return 0.1;
      case DesignatedDriverStatus.driverAssigned: return 0.25;
      case DesignatedDriverStatus.driverArriving: return 0.4;
      case DesignatedDriverStatus.arrived: return 0.55;
      case DesignatedDriverStatus.inspecting: return 0.65;
      case DesignatedDriverStatus.inspectionConfirmed: return 0.75;
      case DesignatedDriverStatus.driving: return 0.85;
      case DesignatedDriverStatus.arrivedDestination: return 0.95;
      case DesignatedDriverStatus.completed: return 1.0;
      case DesignatedDriverStatus.cancelled: return 0.0;
    }
  }

  Widget _buildDriverProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.greenBg,
                child: Text('👨‍✈️', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(_order.driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Đã xác minh GPLX', style: TextStyle(color: AppColors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text('⭐ ${_order.driverRating}', style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        const Text('• 8+ năm kinh nghiệm lái xe', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                      ],
                    ),
                    if (_order.shadowDriverName != null) ...[
                      const SizedBox(height: 4),
                      Text('🛵 ${_order.shadowDriverName}', style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.green),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đang kết nối tới ${_order.driverName}...'), backgroundColor: AppColors.green),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: AppColors.blue),
                onPressed: () => Navigator.pushNamed(context, '/chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🚘', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Phương tiện của bạn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8)),
                child: Text(_order.mode.title, style: const TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildVehicleTag('Xe', _order.vehicleModel),
              const SizedBox(width: 8),
              _buildVehicleTag('Biển số', _order.licensePlate),
              const SizedBox(width: 8),
              _buildVehicleTag('Màu', _order.vehicleColor),
            ],
          ),
          if (_order.parkingLocationNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('📍 Vị trí đỗ: ${_order.parkingLocationNote}', style: const TextStyle(fontSize: 11, color: AppColors.text3)),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleTag(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionCard() {
    final insp = _order.inspection;
    final isConfirmed = insp?.customerConfirmed ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isConfirmed ? AppColors.green.withValues(alpha: 0.5) : AppColors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📸', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text('Biên bản kiểm tra xe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isConfirmed ? AppColors.greenBg : AppColors.orangeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isConfirmed ? 'Đã duyệt' : 'Cần duyệt',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isConfirmed ? AppColors.green : AppColors.orange),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showInspectionModal,
                child: const Text('Xem 4 góc ảnh', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Đồng hồ ODO: ${insp?.odometerKm ?? 0} km', style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Nhiên liệu: ${insp?.fuelLevel ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Vết trầy xước có sẵn được ghi nhận:', style: TextStyle(fontSize: 11, color: AppColors.text3)),
          const SizedBox(height: 4),
          ...?insp?.existingDamages.map((d) => Row(
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.orange, fontSize: 12)),
                  Expanded(child: Text(d, style: const TextStyle(fontSize: 11, color: AppColors.text2))),
                ],
              )),
          if (!isConfirmed) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _order.inspection?.customerConfirmed = true;
                  _order.status = DesignatedDriverStatus.inspectionConfirmed;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xác nhận biên bản bàn giao xe an toàn!'), backgroundColor: AppColors.green),
                );
              },
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('Tôi xác nhận tình trạng xe để bắt đầu lái'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('📍', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Điểm đón xe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                    Text(_order.pickupAddress, style: const TextStyle(fontSize: 11, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(margin: const EdgeInsets.only(left: 15), height: 16, width: 2, color: AppColors.border),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('🏁', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Điểm trả xe (Nhà bạn)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                    Text(_order.dropoffAddress, style: const TextStyle(fontSize: 11, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
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
          const Text('Chi tiết cước phí', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 10),
          _buildPriceRow('Cước mở cuốc', _formatVND(_order.baseFare)),
          const SizedBox(height: 6),
          _buildPriceRow('Cước quãng đường (${_order.distanceKm} km)', _formatVND(_order.kmFare)),
          if (_order.nightSurcharge > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Phụ thu đêm khuya (+30%)', _formatVND(_order.nightSurcharge)),
          ],
          if (_order.shadowDriverFee > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow('Phí Shadow Driver', _formatVND(_order.shadowDriverFee)),
          ],
          const Divider(color: AppColors.border, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thanh toán:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
              Text(_formatVND(_order.totalFare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.green)),
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

  Widget _buildSimulationControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎮', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text('Mô phỏng quy trình lái xe hộ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.green)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _advanceState,
            icon: const Icon(Icons.fast_forward, size: 18),
            label: Text('Bước tiếp: ${_getNextStepLabel()}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextStepLabel() {
    switch (_order.status) {
      case DesignatedDriverStatus.created: return 'Tài xế nhận cuốc';
      case DesignatedDriverStatus.driverAssigned: return 'Tài xế đang đến';
      case DesignatedDriverStatus.driverArriving: return 'Tài xế đã đến điểm đỗ xe';
      case DesignatedDriverStatus.arrived: return 'Bắt đầu kiểm tra xe';
      case DesignatedDriverStatus.inspecting: return 'Khách duyệt biên bản';
      case DesignatedDriverStatus.inspectionConfirmed: return 'Bắt đầu lái xe';
      case DesignatedDriverStatus.driving: return 'Đã đến điểm trả';
      case DesignatedDriverStatus.arrivedDestination: return 'Bàn giao xe hoàn tất';
      case DesignatedDriverStatus.completed: return 'Đã hoàn thành';
      case DesignatedDriverStatus.cancelled: return 'Đã hủy';
    }
  }

  void _showInspectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text('📸', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text('Ảnh chụp 4 góc xe (Vehicle Inspection)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Tài xế đã chụp ảnh lưu trữ trên hệ thống để đảm bảo minh bạch tình trạng xe:', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  _buildPhotoItem('Đầu xe (Front)', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=400'),
                  _buildPhotoItem('Đuôi xe (Back)', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=400'),
                  _buildPhotoItem('Hông trái (Left)', 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=400'),
                  _buildPhotoItem('Hông phải (Right)', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=400'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chi tiết kỹ thuật bàn giao:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text('• Số km hiển thị đồng hồ: ${_order.inspection?.odometerKm ?? 42150} km', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                    Text('• Mức nhiên liệu: ${_order.inspection?.fuelLevel ?? "3/4 bình xăng"}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                    const Text('• Hệ thống phanh, đèn chiếu sáng, lốp xe: Hoạt động bình thường', style: TextStyle(fontSize: 11, color: AppColors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _order.inspection?.customerConfirmed = true;
                    _order.status = DesignatedDriverStatus.inspectionConfirmed;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Xác nhận biên bản kiểm tra xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoItem(String title, String url) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car, color: AppColors.blue, size: 36),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.text)),
          const Text('Đã tải lên • Xem HD', style: TextStyle(fontSize: 9, color: AppColors.text3)),
        ],
      ),
    );
  }

  void _showCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏁', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 12),
              const Text('Đã về nhà an toàn!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
              const SizedBox(height: 6),
              Text(
                'Tài xế ${_order.driverName} đã đưa bạn và phương tiện về tới nơi nguyên vẹn. Cảm ơn bạn đã luôn có trách nhiệm khi tham gia giao thông!',
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
                  backgroundColor: AppColors.green,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hoàn tất chuyến đi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatVND(int amount) {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (m) => '${m[1]}.')} đ';
  }
}
