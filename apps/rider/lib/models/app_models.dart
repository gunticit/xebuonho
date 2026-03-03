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
