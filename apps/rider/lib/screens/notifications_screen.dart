import 'package:flutter/material.dart';
import '../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _notifications = [
    {'type': 'ride', 'title': 'Chuyến xe hoàn thành', 'msg': 'Chuyến Q.1 → Q.7, 35.000đ', 'time': '5 phút trước', 'read': false},
    {'type': 'promo', 'title': 'Flash Sale!', 'msg': 'Giảm 30% cho 3 chuyến tiếp theo', 'time': '1 giờ trước', 'read': false},
    {'type': 'system', 'title': 'Cập nhật ứng dụng', 'msg': 'Phiên bản 2.0 đã sẵn sàng', 'time': '3 giờ trước', 'read': false},
    {'type': 'ride', 'title': 'Đánh giá chuyến đi', 'msg': 'Bạn đánh giá tài xế Nguyễn Văn B thế nào?', 'time': 'Hôm qua', 'read': true},
    {'type': 'order', 'title': 'Đơn GrabFood đã giao', 'msg': 'Đơn #1234 - Phở 24 đã giao thành công', 'time': 'Hôm qua', 'read': true},
    {'type': 'promo', 'title': 'Điểm thưởng', 'msg': 'Bạn nhận được 50 điểm từ chuyến vừa rồi', 'time': '2 ngày trước', 'read': true},
    {'type': 'system', 'title': 'Bảo mật', 'msg': 'Đăng nhập mới từ thiết bị Chrome', 'time': '3 ngày trước', 'read': true},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: Row(
          children: [
            const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              for (var n in _notifications) { n['read'] = true; }
            }),
            child: const Text('Đọc hết', style: TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.text3,
          indicatorColor: AppColors.blue,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Chuyến đi'),
            Tab(text: 'Khuyến mãi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList(_notifications),
          _buildList(_notifications.where((n) => n['type'] == 'ride' || n['type'] == 'order').toList()),
          _buildList(_notifications.where((n) => n['type'] == 'promo').toList()),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔕', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text('Chưa có thông báo', style: TextStyle(color: AppColors.text3)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildItem(items[i]),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final icons = {'ride': '🚗', 'order': '📦', 'promo': '🎉', 'system': '🔔'};
    final colors = {'ride': AppColors.green, 'order': AppColors.orange, 'promo': AppColors.purple, 'system': AppColors.blue};
    final isUnread = n['read'] == false;

    return GestureDetector(
      onTap: () => setState(() => n['read'] = true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.blueBg : AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? AppColors.blue.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (colors[n['type']] ?? AppColors.blue).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(icons[n['type']] ?? '🔔', style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n['title'] ?? '', style: TextStyle(
                          fontSize: 14, fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                          color: isUnread ? AppColors.text : AppColors.text2,
                        )),
                      ),
                      if (isUnread)
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n['msg'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.text3)),
                  const SizedBox(height: 4),
                  Text(n['time'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
