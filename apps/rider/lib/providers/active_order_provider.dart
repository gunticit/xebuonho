import 'package:flutter/material.dart';
import '../models/app_models.dart';

enum ActiveOrderType {
  ride,
  food,
  grocery,
  designatedDriver,
  delivery,
}

class ActiveOrderEntry {
  final String id;
  final ActiveOrderType type;
  final String title;
  final String subtitle;
  final String statusText;
  final String emoji;
  final String routePath;
  final Object? routeArguments;
  final int etaMinutes;
  final double progress; // 0.0 to 1.0

  ActiveOrderEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.emoji,
    required this.routePath,
    this.routeArguments,
    this.etaMinutes = 15,
    this.progress = 0.5,
  });
}

class ActiveOrderProvider extends ChangeNotifier {
  final List<ActiveOrderEntry> _activeOrders = [
    // Pre-seed an active food order so user sees the multi-service banner right away
    ActiveOrderEntry(
      id: 'FOOD-5821',
      type: ActiveOrderType.food,
      title: 'Phở Thìn Lò Đúc - Q.1',
      subtitle: '2x Phở tái lăn, 1x Trà đá',
      statusText: 'Tài xế đang giao đồ ăn',
      emoji: '🍜',
      routePath: '/order-tracking',
      etaMinutes: 12,
      progress: 0.75,
    ),
  ];

  List<ActiveOrderEntry> get activeOrders => _activeOrders;
  bool get hasActiveOrders => _activeOrders.isNotEmpty;
  ActiveOrderEntry? get primaryActiveOrder => _activeOrders.isNotEmpty ? _activeOrders.first : null;

  void addOrder(ActiveOrderEntry order) {
    _activeOrders.removeWhere((o) => o.id == order.id);
    _activeOrders.insert(0, order);
    notifyListeners();
  }

  void removeOrder(String id) {
    _activeOrders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  void addRideOrder({
    required String id,
    required String vehicleType,
    required String dropoffAddress,
    required String driverName,
  }) {
    addOrder(ActiveOrderEntry(
      id: id,
      type: ActiveOrderType.ride,
      title: 'Chuyến xe $vehicleType',
      subtitle: dropoffAddress,
      statusText: 'Tài xế $driverName đang đến',
      emoji: vehicleType == 'Ô tô' ? '🚗' : '🛵',
      routePath: '/tracking',
      etaMinutes: 5,
      progress: 0.35,
    ));
  }

  void addDesignatedOrder(DesignatedDriverOrder order) {
    addOrder(ActiveOrderEntry(
      id: order.id,
      type: ActiveOrderType.designatedDriver,
      title: 'Lái xe hộ: ${order.vehicleModel}',
      subtitle: 'Đưa về: ${order.dropoffAddress}',
      statusText: order.status.label,
      emoji: '🚙',
      routePath: '/designated-tracking',
      routeArguments: order,
      etaMinutes: 8,
      progress: 0.4,
    ));
  }

  void addGroceryOrder(GroceryOrder order) {
    addOrder(ActiveOrderEntry(
      id: order.id,
      type: ActiveOrderType.grocery,
      title: 'Đi chợ: ${order.store.name}',
      subtitle: '${order.items.length} món • ${order.deliveryAddress}',
      statusText: order.status.label,
      emoji: '🛒',
      routePath: '/grocery-tracking',
      routeArguments: order,
      etaMinutes: 25,
      progress: 0.55,
    ));
  }
}
