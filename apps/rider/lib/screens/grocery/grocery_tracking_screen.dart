import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/app_models.dart';

class GroceryTrackingScreen extends StatefulWidget {
  final GroceryOrder? order;

  const GroceryTrackingScreen({super.key, this.order});

  @override
  State<GroceryTrackingScreen> createState() => _GroceryTrackingScreenState();
}

class _GroceryTrackingScreenState extends State<GroceryTrackingScreen> {
  late GroceryOrder _order;
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();
    _order = widget.order ?? _createMockOrder();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  GroceryOrder _createMockOrder() {
    final store = MarketStore(
      id: 'coopmart_cq',
      name: 'Co.opmart Cống Quỳnh',
      address: '189 Cống Quỳnh, Q.1',
      category: 'Siêu thị',
      emoji: '🛒',
    );
    return GroceryOrder(
      id: 'GROCERY-89214',
      store: store,
      items: [
        GroceryItem(id: '1', name: 'Thịt ba chỉ heo tươi', quantity: 1, unit: 'kg', estimatedPrice: 140000, isPurchased: true),
        GroceryItem(id: '2', name: 'Rau muống nước', quantity: 2, unit: 'bó', estimatedPrice: 15000, isPurchased: true),
        GroceryItem(id: '3', name: 'Cà chua Đà Lạt', quantity: 1, unit: 'kg', estimatedPrice: 32000, allowSubstitution: true),
        GroceryItem(id: '4', name: 'Trứng gà Ba Huân', quantity: 1, unit: 'hộp', estimatedPrice: 35000),
      ],
      status: GroceryOrderStatus.shopping,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      deliveryAddress: 'Tòa nhà Bitexco, 2 Hải Triều, Q.1',
      paymentMethod: 'Ví Xebuonho',
      estimatedSubtotal: 222000,
      serviceFee: 33300,
      deliveryFee: 18000,
      tip: 10000,
    );
  }

  void _advanceOrderState() {
    setState(() {
      switch (_order.status) {
        case GroceryOrderStatus.created:
          _order.status = GroceryOrderStatus.driverAssigned;
          break;
        case GroceryOrderStatus.driverAssigned:
          _order.status = GroceryOrderStatus.driverToStore;
          break;
        case GroceryOrderStatus.driverToStore:
          _order.status = GroceryOrderStatus.atStore;
          break;
        case GroceryOrderStatus.atStore:
          _order.status = GroceryOrderStatus.shopping;
          _order.items[0].isPurchased = true;
          _order.items[1].isPurchased = true;
          break;
        case GroceryOrderStatus.shopping:
          _order.status = GroceryOrderStatus.substitutionPending;
          _showSubstitutionModal();
          break;
        case GroceryOrderStatus.substitutionPending:
          _order.status = GroceryOrderStatus.shoppingDone;
          break;
        case GroceryOrderStatus.shoppingDone:
          _order.status = GroceryOrderStatus.receiptUploaded;
          _order.receiptImageUrl = 'https://images.unsplash.com/photo-1554415707-9e49018a382b?w=400';
          _order.actualSubtotal = 228000;
          _showReceiptModal();
          break;
        case GroceryOrderStatus.receiptUploaded:
          _order.status = GroceryOrderStatus.delivering;
          break;
        case GroceryOrderStatus.delivering:
          _order.status = GroceryOrderStatus.delivered;
          _showCompletedDialog();
          break;
        case GroceryOrderStatus.delivered:
        case GroceryOrderStatus.cancelled:
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
            Text('Đơn hàng #${_order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
            Text('${_order.store.name} • ${_order.status.label}', style: const TextStyle(fontSize: 12, color: AppColors.text3)),
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
            _buildDriverCard(),
            const SizedBox(height: 16),
            _buildStoreAndRouteCard(),
            const SizedBox(height: 16),
            _buildShoppingChecklistCard(),
            const SizedBox(height: 16),
            if (_order.status == GroceryOrderStatus.substitutionPending) ...[
              _buildSubstitutionAlertCard(),
              const SizedBox(height: 16),
            ],
            if (_order.actualSubtotal != null || _order.receiptImageUrl != null) ...[
              _buildReceiptCard(),
              const SizedBox(height: 16),
            ],
            _buildPricingSummaryCard(),
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
            AppColors.purple.withValues(alpha: 0.2),
            AppColors.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.purpleBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
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
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _getProgressValue(),
              backgroundColor: AppColors.bg3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription() {
    switch (_order.status) {
      case GroceryOrderStatus.created:
        return 'Hệ thống đang kết nối tài xế gần chợ nhất...';
      case GroceryOrderStatus.driverAssigned:
        return 'Tài xế ${_order.driverName} đã nhận đơn và chuẩn bị đi';
      case GroceryOrderStatus.driverToStore:
        return 'Tài xế đang di chuyển tới ${_order.store.name}';
      case GroceryOrderStatus.atStore:
        return 'Tài xế đã đến chợ và bắt đầu kiểm tra danh sách';
      case GroceryOrderStatus.shopping:
        return 'Đang nhặt đồ tươi ngon theo đúng yêu cầu của bạn';
      case GroceryOrderStatus.substitutionPending:
        return 'Có món hết hàng! Vui lòng xác nhận đề xuất thay thế';
      case GroceryOrderStatus.shoppingDone:
        return 'Đã mua đủ các món! Đang chụp hóa đơn chợ';
      case GroceryOrderStatus.receiptUploaded:
        return 'Hóa đơn đã được tải lên để đối chiếu giá minh bạch';
      case GroceryOrderStatus.delivering:
        return 'Tài xế đang mang đồ tươi sống đến điểm giao hàng';
      case GroceryOrderStatus.delivered:
        return 'Đã giao hàng thành công! Chúc bạn nấu ăn ngon miệng';
      case GroceryOrderStatus.cancelled:
        return 'Đơn hàng đã được hủy';
    }
  }

  double _getProgressValue() {
    switch (_order.status) {
      case GroceryOrderStatus.created: return 0.1;
      case GroceryOrderStatus.driverAssigned: return 0.25;
      case GroceryOrderStatus.driverToStore: return 0.4;
      case GroceryOrderStatus.atStore: return 0.5;
      case GroceryOrderStatus.shopping: return 0.65;
      case GroceryOrderStatus.substitutionPending: return 0.7;
      case GroceryOrderStatus.shoppingDone: return 0.8;
      case GroceryOrderStatus.receiptUploaded: return 0.85;
      case GroceryOrderStatus.delivering: return 0.95;
      case GroceryOrderStatus.delivered: return 1.0;
      case GroceryOrderStatus.cancelled: return 0.0;
    }
  }

  Widget _buildDriverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.blueBg,
            child: Text('👨‍🌾', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_order.driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text)),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Text('⭐ 4.95', style: TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Text('• 1.250+ đơn đi chợ', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.green),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đang gọi cho ${_order.driverName}...'), backgroundColor: AppColors.green),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.blue),
            onPressed: () => Navigator.pushNamed(context, '/chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreAndRouteCard() {
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
                decoration: BoxDecoration(color: AppColors.purpleBg, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(_order.store.emoji, style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_order.store.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                    Text(_order.store.address, style: const TextStyle(fontSize: 11, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                child: const Center(child: Text('📍', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Điểm giao nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                    Text(_order.deliveryAddress, style: const TextStyle(fontSize: 11, color: AppColors.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingChecklistCard() {
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
                  Text('🛒', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Tiến độ mua sắm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
                ],
              ),
              Text(
                '${_order.items.where((i) => i.isPurchased).length}/${_order.items.length} món',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order.items.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.border.withValues(alpha: 0.4), height: 12),
            itemBuilder: (context, index) {
              final item = _order.items[index];
              return Row(
                children: [
                  Icon(
                    item.isPurchased ? Icons.check_circle : (item.isSubstituted ? Icons.published_with_changes : Icons.radio_button_unchecked),
                    color: item.isPurchased ? AppColors.green : (item.isSubstituted ? AppColors.orange : AppColors.text3),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.isSubstituted ? '${item.name} ➔ ${item.substitutionName}' : item.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.isPurchased ? AppColors.text : AppColors.text2,
                            decoration: item.isPurchased ? TextDecoration.none : null,
                          ),
                        ),
                        if (item.isSubstituted)
                          const Text('Đã đổi theo gợi ý tài xế', style: TextStyle(fontSize: 10, color: AppColors.orange)),
                      ],
                    ),
                  ),
                  Text(
                    '${item.quantity} ${item.unit}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text2),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubstitutionAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Tài xế đề xuất thay thế sản phẩm', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Hết "Cà chua Đà Lạt" (32.000đ/kg). Tài xế đề xuất đổi sang "Cà chua bi Hà Lan" (28.000đ/hộp 500g).',
            style: TextStyle(fontSize: 13, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _order.items[2].isPurchased = false;
                      _order.status = GroceryOrderStatus.shopping;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã bỏ qua món này!'), backgroundColor: AppColors.red),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text2,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Bỏ qua món'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _order.items[2].isSubstituted = true;
                      _order.items[2].substitutionName = 'Cà chua bi Hà Lan';
                      _order.items[2].substitutionPrice = 28000;
                      _order.items[2].isPurchased = true;
                      _order.status = GroceryOrderStatus.shopping;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đồng ý thay thế sản phẩm!'), backgroundColor: AppColors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đồng ý đổi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🧾', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Hóa đơn siêu thị thực tế', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
                ],
              ),
              GestureDetector(
                onTap: _showReceiptModal,
                child: const Text('Xem ảnh hóa đơn', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tiền hàng thực tế (Hóa đơn):', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              Text(_formatVND(_order.actualSubtotal ?? _order.estimatedSubtotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.green)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chênh lệch với ước tính:', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              Text(
                '+${_formatVND((_order.actualSubtotal ?? _order.estimatedSubtotal) - _order.estimatedSubtotal)}',
                style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSummaryCard() {
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
          const Text('Chi tiết thanh toán', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tiền hàng:', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              Text(_formatVND(_order.actualSubtotal ?? _order.estimatedSubtotal), style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Phí mua hộ (15%):', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              Text(_formatVND(_order.serviceFee), style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Phí giao hàng:', style: TextStyle(fontSize: 13, color: AppColors.text2)),
              Text(_formatVND(_order.deliveryFee), style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_order.tip > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tiền tip:', style: TextStyle(fontSize: 13, color: AppColors.text2)),
                Text(_formatVND(_order.tip), style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const Divider(color: AppColors.border, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thanh toán:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
              Text(_formatVND(_order.finalTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎮', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text('Bộ điều khiển mô phỏng tài xế', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.blue)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _advanceOrderState,
            icon: const Icon(Icons.fast_forward, size: 18),
            label: Text('Mô phỏng bước tiếp theo: ${_getNextStepLabel()}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
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
      case GroceryOrderStatus.created: return 'Tài xế nhận đơn';
      case GroceryOrderStatus.driverAssigned: return 'Tài xế đi tới chợ';
      case GroceryOrderStatus.driverToStore: return 'Tài xế tới chợ';
      case GroceryOrderStatus.atStore: return 'Bắt đầu nhặt hàng';
      case GroceryOrderStatus.shopping: return 'Báo đổi món (Hết hàng)';
      case GroceryOrderStatus.substitutionPending: return 'Mua sắm hoàn tất';
      case GroceryOrderStatus.shoppingDone: return 'Upload hóa đơn';
      case GroceryOrderStatus.receiptUploaded: return 'Bắt đầu giao hàng';
      case GroceryOrderStatus.delivering: return 'Giao thành công';
      case GroceryOrderStatus.delivered: return 'Đã hoàn thành';
      case GroceryOrderStatus.cancelled: return 'Đã hủy';
    }
  }

  void _showSubstitutionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('⚠️ Hết hàng cần xác nhận!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.orange)),
              const SizedBox(height: 12),
              const Text(
                'Tài xế tại siêu thị thông báo: Món "Cà chua Đà Lạt" hiện tại đã hết hàng tươi ngon.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.text2),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: const Row(
                  children: [
                    Text('🍅', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đề xuất: Cà chua bi Hà Lan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text)),
                          Text('Hộp 500g • Giá: 28.000đ (Rẻ hơn 4.000đ)', style: TextStyle(fontSize: 12, color: AppColors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _order.items[2].isPurchased = false;
                          _order.status = GroceryOrderStatus.shopping;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text2,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _order.items[2].isSubstituted = true;
                          _order.items[2].substitutionName = 'Cà chua bi Hà Lan';
                          _order.items[2].isPurchased = true;
                          _order.status = GroceryOrderStatus.shopping;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Đồng ý đổi món', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReceiptModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hóa đơn siêu thị', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                    IconButton(icon: const Icon(Icons.close, color: AppColors.text3), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt, size: 50, color: AppColors.green),
                      const SizedBox(height: 8),
                      Text('HÓA ĐƠN BÁN LẺ: ${_order.store.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.text)),
                      const Text('Mã GD: #COOP-998124', style: TextStyle(fontSize: 10, color: AppColors.text3)),
                      const SizedBox(height: 4),
                      Text('TỔNG TIỀN: ${_formatVND(_order.actualSubtotal ?? 228000)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Hóa đơn được tài xế chụp trực tiếp tại quầy thanh toán nhằm đảm bảo tính minh bạch tuyệt đối.', style: TextStyle(fontSize: 12, color: AppColors.text3)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đóng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
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
              const Text('🎉', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 12),
              const Text('Giao hàng thành công!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text('Đơn hàng đi chợ hộ đã được giao tới bạn đầy đủ và tươi ngon.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.text2)),
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
                child: const Text('Về trang chủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
