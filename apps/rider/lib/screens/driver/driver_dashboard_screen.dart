import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../models/driver_models.dart';
import '../../models/ride.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final driver = context.watch<DriverProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.orangeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🚕', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.userName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                Text(
                  '${auth.vehicleModel} • ${auth.licensePlate}',
                  style: const TextStyle(fontSize: 11, color: AppColors.text3),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Switch to Rider Mode Button
          TextButton.icon(
            onPressed: () {
              auth.switchRole('rider');
              Navigator.pushReplacementNamed(context, '/home');
            },
            icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.blue),
            label: const Text(
              'Chế độ Khách',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blue),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.text2),
            tooltip: 'Lịch sử chuyến',
            onPressed: () => Navigator.pushNamed(context, '/driver/history'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Online / Offline Status Toggle Card
                _buildStatusCard(driver),
                const SizedBox(height: 16),

                // 2. Today's Performance Metrics
                _buildMetricsGrid(driver),
                const SizedBox(height: 20),

                // 3. Hotspots / High Demand Areas
                _buildHotspotsCard(),
                const SizedBox(height: 20),

                // 4. Quick Simulator Trigger (For testing & demo)
                if (driver.isOnline && driver.currentTrip == null) ...[
                  _buildSimulatorCard(driver),
                  const SizedBox(height: 20),
                ],

                // 5. Vehicle & Partner Info Card
                _buildVehicleInfoCard(auth),
              ],
            ),
          ),

          // Incoming Ride Request Overlay / Modal
          if (driver.incomingRequest != null)
            _buildIncomingRideSheet(context, driver),

          // Active Trip Overlay (when driver accepted a ride)
          if (driver.currentTrip != null)
            _buildActiveTripOverlay(context, driver),
        ],
      ),
    );
  }

  // ==========================================
  // Status Card (Online / Offline)
  // ==========================================
  Widget _buildStatusCard(DriverProvider driver) {
    final isOnline = driver.isOnline;
    final isBusy = driver.isBusy;

    Color cardBg = isOnline ? AppColors.greenBg : AppColors.bg2;
    Color borderColor = isOnline ? AppColors.green.withValues(alpha: 0.5) : AppColors.border;
    Color statusColor = isBusy
        ? AppColors.orange
        : (isOnline ? AppColors.green : AppColors.text3);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // Glowing status indicator icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Center(
              child: Icon(
                isBusy
                    ? Icons.directions_car
                    : (isOnline ? Icons.radar : Icons.power_settings_new),
                color: statusColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBusy
                      ? 'ĐANG TRONG CHUYẾN'
                      : (isOnline ? 'ĐANG TRỰC TUYẾN' : 'ĐANG NGOẠI TUYẾN'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBusy
                      ? 'Đang phục vụ hành khách'
                      : (isOnline ? 'Sẵn sàng nhận cuốc xe mới' : 'Gạt nút để bắt đầu nhận cuốc'),
                  style: const TextStyle(fontSize: 12, color: AppColors.text3),
                ),
              ],
            ),
          ),
          if (!isBusy)
            Switch.adaptive(
              value: isOnline,
              activeThumbColor: AppColors.green,
              onChanged: (val) => driver.toggleOnline(val),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // Metrics Grid (Thu nhập, Số cuốc, v.v.)
  // ==========================================
  Widget _buildMetricsGrid(DriverProvider driver) {
    final stats = driver.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HIỆU SUẤT HÔM NAY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.text3,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Thu nhập',
                value: '${_formatCurrency(stats.todayEarnings)}đ',
                icon: Icons.account_balance_wallet,
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Cuốc xe',
                value: '${stats.tripsCompleted} chuyến',
                icon: Icons.check_circle_outline,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Đánh giá',
                value: '⭐ ${stats.rating}',
                icon: Icons.star_border,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Tỉ lệ nhận',
                value: '${stats.acceptanceRate}%',
                icon: Icons.thumb_up_alt_outlined,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Hotspots Card (Khu vực nhu cầu cao)
  // ==========================================
  Widget _buildHotspotsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'Khu vực nhu cầu cao (Thưởng nóng)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHotspotItem('Sân bay Tân Sơn Nhất', 'Nhu cầu rất cao • +25.000đ/cuốc', '+25k'),
          const Divider(color: AppColors.border, height: 16),
          _buildHotspotItem('Phố đi bộ Nguyễn Huệ, Q.1', 'Nhu cầu cao • +15.000đ/cuốc', '+15k'),
          const Divider(color: AppColors.border, height: 16),
          _buildHotspotItem('Landmark 81, Bình Thạnh', 'Nhu cầu ổn định • +10.000đ/cuốc', '+10k'),
        ],
      ),
    );
  }

  Widget _buildHotspotItem(String name, String desc, String badge) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.orangeBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
          ),
          child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange)),
        ),
      ],
    );
  }

  // ==========================================
  // Quick Simulator Card
  // ==========================================
  Widget _buildSimulatorCard(DriverProvider driver) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppColors.blue, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo kiểm thử',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue),
                ),
                Text(
                  'Bấm để tạo ngay 1 cuốc xe mô phỏng tới tài xế',
                  style: TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => driver.simulateIncomingRide(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tạo cuốc ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Vehicle Info Card
  // ==========================================
  Widget _buildVehicleInfoCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THÔNG TIN XE ĐỐI TÁC',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Loại xe', auth.vehicleType == 'bike' ? '🏍️ Xe máy 2 bánh' : '🚗 Ô tô 4 chỗ'),
          const SizedBox(height: 8),
          _buildInfoRow('Mẫu xe', auth.vehicleModel),
          const SizedBox(height: 8),
          _buildInfoRow('Biển kiểm soát', auth.licensePlate),
          const SizedBox(height: 8),
          _buildInfoRow('Tình trạng hồ sơ', 'Đã xác thực giấy tờ (Verified)', isSuccess: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSuccess = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSuccess ? AppColors.green : AppColors.text,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Incoming Ride Request Modal (Popup Cuốc xe đến)
  // ==========================================
  Widget _buildIncomingRideSheet(BuildContext context, DriverProvider driver) {
    final req = driver.incomingRequest!;
    final countdown = driver.incomingCountdown;
    final progress = countdown / 15.0;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.orange, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timer progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                ),
              ),
              const SizedBox(height: 12),

              // Title & Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orangeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${req.vehicleType == VehicleType.bike ? '🏍️ Xe máy' : '🚗 Ô tô'} • $countdown giây',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${_formatCurrency(req.driverEarning)}đ',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green),
                      ),
                      Text(
                        'Tổng cước: ${_formatCurrency(req.fare)}đ',
                        style: const TextStyle(fontSize: 11, color: AppColors.text3),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Rider info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.blueBg,
                      child: const Icon(Icons.person, size: 18, color: AppColors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${req.riderName} (⭐ ${req.riderRating})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                    Text(
                      '${req.distanceKm} km (~${req.durationMin}p)',
                      style: const TextStyle(fontSize: 12, color: AppColors.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Locations
              _buildLocationRow(Icons.circle, AppColors.green, 'Điểm đón', req.pickupAddress),
              const SizedBox(height: 8),
              _buildLocationRow(Icons.location_on, AppColors.red, 'Điểm đến', req.dropoffAddress),
              if (req.notes != null) ...[
                const SizedBox(height: 8),
                Text('📝 Ghi chú: ${req.notes}', style: const TextStyle(fontSize: 12, color: AppColors.orange)),
              ],
              const SizedBox(height: 18),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => driver.rejectIncomingRide(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Từ chối', style: TextStyle(color: AppColors.text3, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => driver.acceptIncomingRide(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'CHẤP NHẬN CUỐC ➔',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Active Trip Overlay (Tiến trình cuốc xe)
  // ==========================================
  Widget _buildActiveTripOverlay(BuildContext context, DriverProvider driver) {
    final trip = driver.currentTrip!;
    final req = trip.request;

    String actionLabel = '';
    Color actionColor = AppColors.blue;

    switch (trip.status) {
      case DriverTripStatus.arrivingPickup:
        actionLabel = 'Tôi đã đến điểm đón';
        actionColor = AppColors.orange;
        break;
      case DriverTripStatus.arrivedPickup:
        actionLabel = 'Khách đã lên xe - Bắt đầu đi';
        actionColor = AppColors.blue;
        break;
      case DriverTripStatus.inProgress:
        actionLabel = 'Đã tới nơi - Hoàn thành chuyến';
        actionColor = AppColors.green;
        break;
      default:
        actionLabel = 'Tiếp tục';
        break;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: actionColor, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: actionColor),
                    ),
                    child: Text(
                      trip.status.displayName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: actionColor),
                    ),
                  ),
                  Text(
                    '${_formatCurrency(req.driverEarning)}đ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.green),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Passenger row with Call & Chat buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.blueBg,
                      child: const Icon(Icons.person, color: AppColors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.riderName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                          Text(req.riderPhone, style: const TextStyle(fontSize: 12, color: AppColors.text3)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.green),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đang gọi cho khách: ${req.riderPhone}')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.blue),
                      onPressed: () => Navigator.pushNamed(context, '/chat'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Target location based on status
              if (trip.status == DriverTripStatus.arrivingPickup || trip.status == DriverTripStatus.arrivedPickup)
                _buildLocationRow(Icons.radio_button_checked, AppColors.green, 'Đón khách tại', req.pickupAddress)
              else
                _buildLocationRow(Icons.location_on, AppColors.red, 'Chở khách tới', req.dropoffAddress),

              const SizedBox(height: 20),

              // Big Action Button
              ElevatedButton(
                onPressed: () => driver.advanceTripStatus(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),

              // Cancel button
              TextButton(
                onPressed: () => driver.cancelCurrentTrip(),
                child: const Text('Hủy chuyến', style: TextStyle(color: AppColors.red, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color iconColor, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
              Text(
                address,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
