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
