class SavedAddress {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final AddressType type;
  final String emoji;

  SavedAddress({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
    this.emoji = '📍',
  });
}

enum AddressType {
  home,
  work,
  favorite,
  recent;

  String get displayName {
    switch (this) {
      case AddressType.home: return 'Nhà';
      case AddressType.work: return 'Công ty';
      case AddressType.favorite: return 'Yêu thích';
      case AddressType.recent: return 'Gần đây';
    }
  }

  String get emoji {
    switch (this) {
      case AddressType.home: return '🏠';
      case AddressType.work: return '🏢';
      case AddressType.favorite: return '⭐';
      case AddressType.recent: return '🕐';
    }
  }
}

class Restaurant {
  final String id;
  final String name;
  final String image;
  final String category;
  final double rating;
  final int ratingCount;
  final String distance;
  final String deliveryTime;
  final int deliveryFee;
  final bool isOpen;
  final List<String> tags;
  final List<MenuCategory> menu;

  Restaurant({
    required this.id,
    required this.name,
    required this.image,
    required this.category,
    required this.rating,
    required this.ratingCount,
    required this.distance,
    required this.deliveryTime,
    required this.deliveryFee,
    this.isOpen = true,
    this.tags = const [],
    this.menu = const [],
  });
}

class MenuCategory {
  final String name;
  final List<MenuItem> items;

  MenuCategory({required this.name, required this.items});
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final String image;
  final bool available;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.image = '',
    this.available = true,
  });
}

class CartItem {
  final MenuItem item;
  int quantity;
  String? note;

  CartItem({required this.item, this.quantity = 1, this.note});

  int get total => item.price * quantity;
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final bool isQuickAction;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.isQuickAction = false,
  });
}

// ========== Food Order ==========
enum OrderStatus {
  placed, confirmed, preparing, pickedUp, delivering, delivered, cancelled;

  String get label {
    switch (this) {
      case OrderStatus.placed: return 'Đã đặt';
      case OrderStatus.confirmed: return 'Đã xác nhận';
      case OrderStatus.preparing: return 'Đang chuẩn bị';
      case OrderStatus.pickedUp: return 'Đã lấy hàng';
      case OrderStatus.delivering: return 'Đang giao';
      case OrderStatus.delivered: return 'Đã giao';
      case OrderStatus.cancelled: return 'Đã hủy';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.placed: return '📝';
      case OrderStatus.confirmed: return '✅';
      case OrderStatus.preparing: return '👨‍🍳';
      case OrderStatus.pickedUp: return '🏍️';
      case OrderStatus.delivering: return '🚀';
      case OrderStatus.delivered: return '🎉';
      case OrderStatus.cancelled: return '❌';
    }
  }
}

class FoodOrder {
  final String id;
  final String restaurantName;
  final String restaurantEmoji;
  final List<CartItem> items;
  final OrderStatus status;
  final DateTime createdAt;
  final String deliveryAddress;
  final String paymentMethod;
  final String? note;
  final int subtotal;
  final int deliveryFee;
  final int discount;

  FoodOrder({
    required this.id,
    required this.restaurantName,
    this.restaurantEmoji = '🍜',
    required this.items,
    this.status = OrderStatus.placed,
    required this.createdAt,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.note,
    required this.subtotal,
    required this.deliveryFee,
    this.discount = 0,
  });

  int get total => subtotal + deliveryFee - discount;
}

class ShareBillMember {
  final String name;
  final List<CartItem> items;
  int amount;
  bool paid;

  ShareBillMember({required this.name, this.items = const [], required this.amount, this.paid = false});
}

// ========== Grocery Shopping Models ==========
class MarketStore {
  final String id;
  final String name;
  final String address;
  final String category; // 'Siêu thị', 'Chợ truyền thống', 'Cửa hàng tiện lợi'
  final String emoji;
  final double rating;
  final String distance;
  final String openHours;

  MarketStore({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    this.emoji = '🛒',
    this.rating = 4.8,
    this.distance = '1.2 km',
    this.openHours = '06:00 - 22:00',
  });
}

class GroceryItem {
  final String id;
  final String name;
  int quantity;
  final String unit; // 'kg', 'bó', 'túi', 'hộp', 'chai', 'khay', 'gói'
  final int estimatedPrice;
  int? actualPrice;
  final String? note;
  final bool allowSubstitution;
  String? substitutionName;
  int? substitutionPrice;
  bool isSubstituted;
  bool? substitutionApproved;
  bool isPurchased;

  GroceryItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = 'kg',
    this.estimatedPrice = 30000,
    this.actualPrice,
    this.note,
    this.allowSubstitution = true,
    this.substitutionName,
    this.substitutionPrice,
    this.isSubstituted = false,
    this.substitutionApproved,
    this.isPurchased = false,
  });

  int get totalEstimated => estimatedPrice * quantity;
  int get totalActual => (actualPrice ?? (isSubstituted ? (substitutionPrice ?? estimatedPrice) : estimatedPrice)) * quantity;
}

enum GroceryOrderStatus {
  created,
  driverAssigned,
  driverToStore,
  atStore,
  shopping,
  substitutionPending,
  shoppingDone,
  receiptUploaded,
  delivering,
  delivered,
  cancelled;

  String get label {
    switch (this) {
      case GroceryOrderStatus.created: return 'Đang tìm tài xế';
      case GroceryOrderStatus.driverAssigned: return 'Tài xế đã nhận';
      case GroceryOrderStatus.driverToStore: return 'Tài xế đang đến chợ';
      case GroceryOrderStatus.atStore: return 'Tài xế đã đến chợ';
      case GroceryOrderStatus.shopping: return 'Đang mua sắm';
      case GroceryOrderStatus.substitutionPending: return 'Cần xác nhận thay thế';
      case GroceryOrderStatus.shoppingDone: return 'Đã mua xong';
      case GroceryOrderStatus.receiptUploaded: return 'Đã upload hóa đơn';
      case GroceryOrderStatus.delivering: return 'Đang giao hàng';
      case GroceryOrderStatus.delivered: return 'Giao thành công';
      case GroceryOrderStatus.cancelled: return 'Đã hủy';
    }
  }

  String get emoji {
    switch (this) {
      case GroceryOrderStatus.created: return '🔍';
      case GroceryOrderStatus.driverAssigned: return '🏍️';
      case GroceryOrderStatus.driverToStore: return '🛵';
      case GroceryOrderStatus.atStore: return '🏪';
      case GroceryOrderStatus.shopping: return '🛒';
      case GroceryOrderStatus.substitutionPending: return '⚠️';
      case GroceryOrderStatus.shoppingDone: return '✅';
      case GroceryOrderStatus.receiptUploaded: return '🧾';
      case GroceryOrderStatus.delivering: return '🚀';
      case GroceryOrderStatus.delivered: return '🎉';
      case GroceryOrderStatus.cancelled: return '❌';
    }
  }
}

class GroceryOrder {
  final String id;
  final MarketStore store;
  final List<GroceryItem> items;
  GroceryOrderStatus status;
  final DateTime createdAt;
  final String deliveryAddress;
  final String paymentMethod;
  final String? note;
  final int estimatedSubtotal;
  int? actualSubtotal;
  final int serviceFee;
  final int deliveryFee;
  final int tip;
  String? receiptImageUrl;
  final String driverName;
  final String driverPhone;

  GroceryOrder({
    required this.id,
    required this.store,
    required this.items,
    this.status = GroceryOrderStatus.created,
    required this.createdAt,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.note,
    required this.estimatedSubtotal,
    this.actualSubtotal,
    required this.serviceFee,
    required this.deliveryFee,
    this.tip = 0,
    this.receiptImageUrl,
    this.driverName = 'Nguyễn Văn Toàn',
    this.driverPhone = '0908 123 456',
  });

  int get estimatedTotal => estimatedSubtotal + serviceFee + deliveryFee + tip;
  int get finalTotal => (actualSubtotal ?? estimatedSubtotal) + serviceFee + deliveryFee + tip;
}

// ========== Designated Driver Models ==========
enum DesignatedDriverMode {
  solo,
  duo;

  String get title {
    switch (this) {
      case DesignatedDriverMode.solo: return 'Solo (Tài xế đi xe gập)';
      case DesignatedDriverMode.duo: return 'Duo (2 tài xế - Shadow Driver)';
    }
  }

  String get description {
    switch (this) {
      case DesignatedDriverMode.solo: return 'Tài xế đi xe gấp bỏ cốp xe của bạn, tiết kiệm chi phí';
      case DesignatedDriverMode.duo: return 'Tài xế chính lái xe khách + 1 tài xế chạy sau chở về';
    }
  }

  String get emoji {
    switch (this) {
      case DesignatedDriverMode.solo: return '🛴';
      case DesignatedDriverMode.duo: return '👥';
    }
  }
}

class VehicleInspection {
  final int odometerKm;
  final String fuelLevel; // '1/4', '1/2', '3/4', 'Đầy bình'
  final String photoFront;
  final String photoBack;
  final String photoLeft;
  final String photoRight;
  final List<String> existingDamages;
  bool customerConfirmed;
  final DateTime inspectedAt;

  VehicleInspection({
    required this.odometerKm,
    required this.fuelLevel,
    required this.photoFront,
    required this.photoBack,
    required this.photoLeft,
    required this.photoRight,
    this.existingDamages = const [],
    this.customerConfirmed = false,
    required this.inspectedAt,
  });
}

enum DesignatedDriverStatus {
  created,
  driverAssigned,
  driverArriving,
  arrived,
  inspecting,
  inspectionConfirmed,
  driving,
  arrivedDestination,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case DesignatedDriverStatus.created: return 'Đang tìm tài xế';
      case DesignatedDriverStatus.driverAssigned: return 'Đã tìm thấy tài xế';
      case DesignatedDriverStatus.driverArriving: return 'Tài xế đang đến vị trí xe';
      case DesignatedDriverStatus.arrived: return 'Tài xế đã đến';
      case DesignatedDriverStatus.inspecting: return 'Đang kiểm tra xe (Inspection)';
      case DesignatedDriverStatus.inspectionConfirmed: return 'Đã xác nhận biên bản xe';
      case DesignatedDriverStatus.driving: return 'Đang lái xe đưa bạn về';
      case DesignatedDriverStatus.arrivedDestination: return 'Đã đến điểm trả';
      case DesignatedDriverStatus.completed: return 'Bàn giao xe & Hoàn thành';
      case DesignatedDriverStatus.cancelled: return 'Đã hủy';
    }
  }

  String get emoji {
    switch (this) {
      case DesignatedDriverStatus.created: return '🔍';
      case DesignatedDriverStatus.driverAssigned: return '👨‍✈️';
      case DesignatedDriverStatus.driverArriving: return '🛵';
      case DesignatedDriverStatus.arrived: return '📍';
      case DesignatedDriverStatus.inspecting: return '📸';
      case DesignatedDriverStatus.inspectionConfirmed: return '📝';
      case DesignatedDriverStatus.driving: return '🚗';
      case DesignatedDriverStatus.arrivedDestination: return '🏁';
      case DesignatedDriverStatus.completed: return '🎉';
      case DesignatedDriverStatus.cancelled: return '❌';
    }
  }
}

class DesignatedDriverOrder {
  final String id;
  final String vehicleType; // 'Ô tô' hoặc 'Xe máy'
  final String vehicleModel; // 'Mazda 3', 'Toyota Camry', 'SH 150i'
  final String licensePlate; // '51K-987.65'
  final String vehicleColor;
  final String pickupAddress;
  final String dropoffAddress;
  final String parkingLocationNote;
  final DesignatedDriverMode mode;
  DesignatedDriverStatus status;
  final DateTime createdAt;
  final String paymentMethod;
  final double distanceKm;
  final int baseFare;
  final int kmFare;
  final int nightSurcharge;
  final int shadowDriverFee;
  final int totalFare;
  final String driverName;
  final String driverPhone;
  final String driverRating;
  final String? shadowDriverName;
  VehicleInspection? inspection;

  DesignatedDriverOrder({
    required this.id,
    this.vehicleType = 'Ô tô',
    required this.vehicleModel,
    required this.licensePlate,
    required this.vehicleColor,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.parkingLocationNote = '',
    this.mode = DesignatedDriverMode.solo,
    this.status = DesignatedDriverStatus.created,
    required this.createdAt,
    required this.paymentMethod,
    required this.distanceKm,
    required this.baseFare,
    required this.kmFare,
    this.nightSurcharge = 0,
    this.shadowDriverFee = 0,
    required this.totalFare,
    this.driverName = 'Trần Hữu Thắng',
    this.driverPhone = '0912 345 678',
    this.driverRating = '4.95',
    this.shadowDriverName,
    this.inspection,
  });
}

