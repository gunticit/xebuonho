import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';

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

  final _vehicles = [
    {'id': 'bike', 'emoji': '🏍️', 'name': 'Xe máy', 'price': '~25.000đ'},
    {'id': 'car', 'emoji': '🚗', 'name': 'Ô tô', 'price': '~75.000đ'},
    {'id': 'premium', 'emoji': '🚙', 'name': 'Premium', 'price': '~120.000đ'},
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

  void _confirmSchedule() {
    if (_pickup.trim().isEmpty || _dropoff.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('⚠️ Vui lòng nhập điểm đón và điểm đến'), backgroundColor: AppColors.orange),
      );
      return;
    }
    final fmt = DateFormat('HH:mm — EEE, dd/MM', 'vi_VN');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🎉', style: TextStyle(fontSize: 28)),
          SizedBox(width: 10),
          Text('Đã đặt lịch!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Chuyến của bạn đã được lên lịch:', style: TextStyle(fontSize: 13, color: AppColors.text3)),
          const SizedBox(height: 12),
          _kv('🕐 Thời gian', fmt.format(_scheduled)),
          _kv('🚦 Loại xe', _vehicles.firstWhere((v) => v['id'] == _vehicle)['name']!),
          _kv('📍 Đón', _pickup),
          _kv('🎯 Đến', _dropoff),
          if (_remind15)
            _kv('🔔 Nhắc nhở', 'Trước 15 phút'),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Đóng', style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 100, child: Text(k, style: TextStyle(fontSize: 12, color: AppColors.text3))),
      Expanded(child: Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, dd/MM/yyyy', 'vi_VN');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('📅 Đặt lịch chuyến xe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.blue.withValues(alpha: 0.15), AppColors.purple.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Text('📅', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Đặt xe trước', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              Text('Chúng tôi sẽ tự ghép tài xế và nhắc bạn đúng giờ', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.text3)),
            ]),
          ),
          const SizedBox(height: 20),

          // Date + Time
          Text('🕐 Thời gian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Icon(Icons.calendar_today, color: AppColors.blue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(dateFmt.format(_scheduled), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
                ]),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Icon(Icons.access_time, color: AppColors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(timeFmt.format(_scheduled), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 20),

          // Pickup / Dropoff
          Text('📍 Hành trình', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: TextField(
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Điểm đón',
                prefixIcon: const Text('🟢', style: TextStyle(fontSize: 16)),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                border: InputBorder.none,
              ),
              onChanged: (v) => _pickup = v,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: TextField(
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Điểm đến',
                prefixIcon: const Text('🔴', style: TextStyle(fontSize: 16)),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                border: InputBorder.none,
              ),
              onChanged: (v) => _dropoff = v,
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle
          Text('🚦 Loại xe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 8),
          ..._vehicles.map((v) => GestureDetector(
            onTap: () => setState(() => _vehicle = v['id']!),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _vehicle == v['id'] ? AppColors.blueBg : AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _vehicle == v['id'] ? AppColors.blue.withValues(alpha: 0.5) : AppColors.border),
              ),
              child: Row(children: [
                Text(v['emoji']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(child: Text(v['name']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text))),
                Text(v['price']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange)),
                if (_vehicle == v['id'])
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(Icons.check_circle, color: AppColors.blue, size: 20),
                  ),
              ]),
            ),
          )),
          const SizedBox(height: 16),

          // Reminder switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _remind15,
              activeColor: AppColors.blue,
              onChanged: (v) => setState(() => _remind15 = v),
              title: Row(children: [
                const Text('🔔', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text('Nhắc nhở trước 15 phút', style: TextStyle(fontSize: 14, color: AppColors.text)),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // Confirm
          GestureDetector(
            onTap: _confirmSchedule,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: const Center(child: Text('Xác nhận đặt lịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
