import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/app_icons.dart';
import '../services/api_service.dart';

class ScheduleRideScreen extends StatefulWidget {
  const ScheduleRideScreen({super.key});

  @override
  State<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends State<ScheduleRideScreen> {
  DateTime _scheduled = DateTime.now().add(const Duration(hours: 1));
  String _vehicle = 'bike';
  String _pickup = '';
  String _dropoff = '';
  bool _remind15 = true;
  bool _isSubmitting = false;

  final _vehicles = [
    {'id': 'bike', 'icon': AppIcons.bike, 'name': 'Xe máy', 'price': '~25.000đ'},
    {'id': 'car', 'icon': AppIcons.car, 'name': 'Ô tô 4 chỗ', 'price': '~75.000đ'},
    {'id': 'premium', 'icon': AppIcons.car, 'name': 'Ô tô 7 chỗ / Premium', 'price': '~120.000đ'},
  ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.blue, surface: AppColors.bg2),
          dialogBackgroundColor: AppColors.bg2,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _scheduled = DateTime(picked.year, picked.month, picked.day, _scheduled.hour, _scheduled.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.blue, surface: AppColors.bg2),
          dialogBackgroundColor: AppColors.bg2,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _scheduled = DateTime(_scheduled.year, _scheduled.month, _scheduled.day, picked.hour, picked.minute));
    }
  }

  String _formatDateVietnamese(DateTime dt) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final weekday = weekdays[(dt.weekday - 1).clamp(0, 6)];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$weekday, $day/$month/$year';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTimeSummary(DateTime dt) {
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
    final weekday = weekdays[(dt.weekday - 1).clamp(0, 6)];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute — $weekday, $day/$month';
  }

  /// Đặt lịch thật: tạo order status='scheduled' + scheduled_at.
  Future<void> _confirmSchedule() async {
    if (_pickup.trim().isEmpty || _dropoff.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập điểm đón và điểm đến'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }
    if (_scheduled.isBefore(DateTime.now().add(const Duration(minutes: 10)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giờ đón phải cách hiện tại ít nhất 10 phút'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      double lat = 12.9247, lng = 108.2541;
      await ApiService().createRide(
        serviceType: 'ride',
        pickupAddress: _pickup,
        pickupLat: lat,
        pickupLng: lng,
        dropoffAddress: _dropoff,
        dropoffLat: lat + 0.02,
        dropoffLng: lng + 0.02,
        vehicleType: _vehicle,
        paymentMethod: 'cash',
        scheduledAt: _scheduled.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      final timeStr = _formatDateTimeSummary(_scheduled);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: Row(
            children: [
              IconContainer(
                icon: AppIcons.verified,
                color: AppColors.green,
                size: 36,
                iconSize: 20,
                borderRadius: AppRadius.sm,
              ),
              const SizedBox(width: 10),
              Text('Đã đặt lịch hẹn!', style: AppTextStyles.heading3.copyWith(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chuyến đi của bạn đã được lên lịch thành công:', style: AppTextStyles.caption),
              const SizedBox(height: 12),
              _kv('Thời gian', timeStr, AppIcons.timer),
              _kv('Loại xe', _vehicles.firstWhere((v) => v['id'] == _vehicle)['name'] as String, AppIcons.car),
              _kv('Điểm đón', _pickup, AppIcons.pickup),
              _kv('Điểm đến', _dropoff, AppIcons.dropoff),
              if (_remind15)
                _kv('Nhắc nhở', 'Trước 15 phút', AppIcons.notifications),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
              child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.card),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không đặt được lịch. Kiểm tra server và thử lại.'), backgroundColor: AppColors.card),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _kv(String k, String v, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.text3),
        const SizedBox(width: 6),
        SizedBox(width: 80, child: Text(k, style: AppTextStyles.caption)),
        Expanded(child: Text(v, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600, color: AppColors.text))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDateVietnamese(_scheduled);
    final timeStr = _formatTime(_scheduled);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: Text('Đặt lịch hẹn chuyến xe', style: AppTextStyles.heading3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Modern Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.blue.withValues(alpha: 0.18), AppColors.purple.withValues(alpha: 0.12)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
              boxShadow: AppShadows.subtle,
            ),
            child: Row(
              children: [
                IconContainer(
                  icon: AppIcons.schedule,
                  color: AppColors.blue,
                  size: 54,
                  iconSize: 28,
                  borderRadius: AppRadius.md,
                  showGlow: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đặt xe theo lịch hẹn', style: AppTextStyles.heading4),
                      const SizedBox(height: 4),
                      Text(
                        'Hệ thống tự động ghép tài xế tốt nhất và thông báo nhắc bạn đúng giờ.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.text2, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Date + Time Section
          Text('Thời gian đón', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.blue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(dateStr, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600, color: AppColors.text))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(AppIcons.timer, color: AppColors.green, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(timeStr, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600, color: AppColors.text))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pickup / Dropoff
          Text('Hành trình', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Nhập địa chỉ đón',
                prefixIcon: Icon(AppIcons.pickup, color: AppColors.green, size: 18),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (v) => _pickup = v,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Nhập địa chỉ đến',
                prefixIcon: Icon(AppIcons.dropoff, color: AppColors.red, size: 18),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (v) => _dropoff = v,
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle Selection
          Text('Chọn phương tiện', style: AppTextStyles.label),
          const SizedBox(height: 8),
          ..._vehicles.map((v) {
            final isSelected = _vehicle == v['id'];
            final icon = v['icon'] as IconData;
            return GestureDetector(
              onTap: () => setState(() => _vehicle = v['id'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blueBg : AppColors.bg2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? AppColors.blue : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected ? AppShadows.glow(AppColors.blue) : null,
                ),
                child: Row(
                  children: [
                    IconContainer(
                      icon: icon,
                      color: isSelected ? AppColors.blue : AppColors.text3,
                      size: 40,
                      iconSize: 20,
                      borderRadius: AppRadius.sm,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        v['name'] as String,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.blue : AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      v['price'] as String,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(AppIcons.verified, color: AppColors.blue, size: 20),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // Reminder switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _remind15,
              activeThumbColor: AppColors.blue,
              onChanged: (v) => setState(() => _remind15 = v),
              title: Row(
                children: [
                  const Icon(AppIcons.notifications, size: 18, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Text('Nhắc nhở trước 15 phút', style: AppTextStyles.body2.copyWith(color: AppColors.text)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Confirm button
          GestureDetector(
            onTap: _isSubmitting ? null : _confirmSchedule,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Xác nhận đặt lịch', style: AppTextStyles.button),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
