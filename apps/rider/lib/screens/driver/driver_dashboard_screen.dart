import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../models/driver_models.dart';

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
            IconContainer(
              icon: AppIcons.car,
              color: AppColors.orange,
              size: 38,
              iconSize: 20,
              borderRadius: AppRadius.sm,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading4.copyWith(fontSize: 15),
                  ),
                  Text(
                    '${auth.vehicleModel} • ${auth.licensePlate}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
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
            icon: const Icon(AppIcons.swap, size: 18, color: AppColors.blue),
            label: Text(
              'Chế độ Khách',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.blue),
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.history, color: AppColors.text2),
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
                // 0. Compliance & Approval Status Banner
                if (!auth.isDriverApproved) ...[
                  _buildApprovalBanner(auth),
                  const SizedBox(height: 16),
                ],

                // 1. Online / Offline Status Toggle Card
                _buildStatusCard(driver, auth),
                const SizedBox(height: 16),

                // 2. Today's Performance Metrics
                _buildMetricsGrid(driver),
                const SizedBox(height: 20),

                // 3. Hotspots / High Demand Areas
                _buildHotspotsCard(),
                const SizedBox(height: 20),

                // 4. Vehicle & Partner Info Card
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
  // Compliance & Approval Banner (NĐ 10/2020)
  // ==========================================
  Widget _buildApprovalBanner(AuthProvider auth) {
    final isPending = auth.approvalStatus == 'pending_approval';
    final isRejected = auth.approvalStatus == 'rejected';

    Color bgColor = isRejected
        ? AppColors.redBg
        : (isPending ? AppColors.orangeBg : AppColors.blueBg);
    Color borderColor = isRejected
        ? AppColors.red.withValues(alpha: 0.5)
        : (isPending ? AppColors.orange.withValues(alpha: 0.5) : AppColors.blue.withValues(alpha: 0.5));
    Color accentColor = isRejected
        ? AppColors.red
        : (isPending ? AppColors.orange : AppColors.blue);
    IconData icon = isRejected
        ? Icons.cancel_outlined
        : (isPending ? Icons.pending_actions_rounded : AppIcons.verified);

    String title = isRejected
        ? 'HỒ SƠ BỊ TỪ CHỐI'
        : (isPending ? 'HỒ SƠ ĐANG CHỜ PHÊ DUYỆT' : 'YÊU CẦU ĐỊNH DANH PHÁP LÝ');

    String desc = isRejected
        ? 'Lý do: ${auth.rejectionReason ?? "Giấy tờ chưa đạt chuẩn theo quy định"}. Vui lòng cập nhật lại hồ sơ.'
        : (isPending
            ? 'Hồ sơ pháp lý của bạn đang được quản trị viên xét duyệt theo NĐ 10/2020/NĐ-CP. Bạn chưa thể bật nhận cuốc lúc này.'
            : 'Vui lòng hoàn tất nộp định danh CCCD và GPLX để được kích hoạt nhận cuốc thương mại.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/driver/kyc'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    isRejected ? 'Sửa hồ sơ' : 'Xem hồ sơ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: AppTextStyles.caption.copyWith(color: AppColors.text2, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _showApprovalRequiredDialog(String status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: const [
            Icon(AppIcons.shield, color: AppColors.orange, size: 24),
            SizedBox(width: 8),
            Text('Chưa thể nhận cuốc', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          status == 'rejected'
              ? 'Hồ sơ đối tác của bạn chưa được duyệt. Vui lòng cập nhật lại thông tin để tiếp tục.'
              : 'Theo quy định thương mại vận tải (NĐ 10/2020/NĐ-CP), bạn chỉ có thể bật nhận cuốc sau khi hồ sơ CCCD, GPLX và đăng ký xe được ban quản trị phê duyệt.',
          style: AppTextStyles.body2.copyWith(color: AppColors.text2, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Đóng', style: AppTextStyles.caption.copyWith(color: AppColors.text3, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/driver/kyc');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Kiểm tra KYC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Status Card (Online / Offline)
  // ==========================================
  Widget _buildStatusCard(DriverProvider driver, AuthProvider auth) {
    final isOnline = driver.isOnline;
    final isBusy = driver.isBusy;
    final isApproved = auth.isDriverApproved;

    Color cardBg = isOnline ? AppColors.greenBg : AppColors.bg2;
    Color borderColor = isOnline ? AppColors.green.withValues(alpha: 0.5) : AppColors.border;
    Color statusColor = isBusy
        ? AppColors.orange
        : (isOnline ? AppColors.green : AppColors.text3);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isOnline ? AppShadows.glow(AppColors.green) : AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Center(
              child: Icon(
                isBusy
                    ? AppIcons.car
                    : (isOnline ? AppIcons.radar : AppIcons.offline),
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
                  !isApproved
                      ? 'Khóa nhận cuốc (Đang chờ duyệt KYC)'
                      : (isBusy
                          ? 'Đang phục vụ hành khách'
                          : (isOnline ? 'Sẵn sàng nhận cuốc xe mới' : 'Gạt nút để bắt đầu nhận cuốc')),
                  style: TextStyle(
                    fontSize: 12,
                    color: !isApproved ? AppColors.orange : AppColors.text3,
                    fontWeight: !isApproved ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!isBusy)
            Switch.adaptive(
              value: isOnline,
              activeThumbColor: AppColors.green,
              onChanged: !isApproved
                  ? (val) => _showApprovalRequiredDialog(auth.approvalStatus)
                  : (val) => driver.toggleOnline(val),
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
        Text(
          'HIỆU SUẤT HÔM NAY',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Thu nhập',
                value: '${_formatCurrency(stats.todayEarnings)}đ',
                icon: AppIcons.earnings,
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Cuốc xe',
                value: '${stats.tripsCompleted} chuyến',
                icon: AppIcons.trips,
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
                value: '${stats.rating} ⭐',
                icon: AppIcons.star,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Tỉ lệ nhận',
                value: '${stats.acceptanceRate}%',
                icon: AppIcons.acceptance,
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
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconContainer(
                icon: icon,
                color: color,
                size: 28,
                iconSize: 16,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(fontSize: 16),
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconContainer(
                icon: AppIcons.hotspot,
                color: AppColors.orange,
                size: 30,
                iconSize: 18,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(width: 10),
              Text(
                'Khu vực nhu cầu cao (Thưởng nóng)',
                style: AppTextStyles.heading4.copyWith(fontSize: 13),
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
              Text(name, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc, style: AppTextStyles.caption),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.orangeBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
          ),
          child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange)),
        ),
      ],
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THÔNG TIN XE ĐỐI TÁC',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Loại xe', auth.vehicleType == 'bike' ? 'Xe máy 2 bánh' : 'Ô tô 4 chỗ', icon: auth.vehicleType == 'bike' ? AppIcons.bike : AppIcons.car),
          const SizedBox(height: 10),
          _buildInfoRow('Mẫu xe', auth.vehicleModel),
          const SizedBox(height: 10),
          _buildInfoRow('Biển kiểm soát', auth.licensePlate),
          const SizedBox(height: 10),
          _buildInfoRow('Tình trạng hồ sơ', 'Đã xác thực giấy tờ (Verified)', isSuccess: true, icon: AppIcons.verified),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSuccess = false, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSuccess ? AppColors.green : AppColors.text3),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppTextStyles.body2),
          ],
        ),
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
      color: Colors.black.withValues(alpha: 0.75),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.orange, width: 2),
            boxShadow: AppShadows.glow(AppColors.orange),
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
              const SizedBox(height: 14),

              // Title & Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.orangeBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.car, size: 14, color: AppColors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${req.serviceType.displayName} • $countdown s',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange),
                        ),
                      ],
                    ),
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
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Rider info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.blueBg,
                      child: const Icon(AppIcons.profile, size: 20, color: AppColors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${req.riderName} (⭐ ${req.riderRating})',
                        style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${req.distanceKm} km (~${req.durationMin}p)',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Locations
              _buildLocationRow(AppIcons.pickup, AppColors.green, 'Điểm đón', req.pickupAddress),
              const SizedBox(height: 8),
              _buildLocationRow(AppIcons.dropoff, AppColors.red, 'Điểm đến', req.dropoffAddress),
              if (req.notes != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(AppIcons.note, size: 14, color: AppColors.orange),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Ghi chú: ${req.notes}', style: const TextStyle(fontSize: 12, color: AppColors.orange))),
                  ],
                ),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: Text('Từ chối', style: AppTextStyles.button.copyWith(color: AppColors.text3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        await driver.acceptIncomingRide();
                        final err = driver.consumeError();
                        if (err != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: AppColors.card),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        elevation: 4,
                        shadowColor: AppColors.green.withValues(alpha: 0.4),
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
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: actionColor, width: 2),
            boxShadow: AppShadows.glow(actionColor),
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.blueBg,
                      child: const Icon(AppIcons.profile, color: AppColors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.riderName, style: AppTextStyles.heading4.copyWith(fontSize: 14)),
                          Text(req.riderPhone, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.call, color: AppColors.green),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đang gọi cho khách: ${req.riderPhone}')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.chat, color: AppColors.blue),
                      onPressed: () => Navigator.pushNamed(context, '/chat'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Target location based on status
              if (trip.status == DriverTripStatus.arrivingPickup || trip.status == DriverTripStatus.arrivedPickup)
                _buildLocationRow(AppIcons.pickup, AppColors.green, 'Đón khách tại', req.pickupAddress)
              else
                _buildLocationRow(AppIcons.dropoff, AppColors.red, 'Chở khách tới', req.dropoffAddress),

              const SizedBox(height: 20),

              // Big Action Button
              ElevatedButton(
                onPressed: () => driver.advanceTripStatus(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 4,
                  shadowColor: actionColor.withValues(alpha: 0.4),
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
                child: Text('Hủy chuyến', style: AppTextStyles.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.bold)),
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
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                address,
                style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
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
