import 'driver.dart';

enum RideStatus {
  created,
  driverAssigned,
  arriving,
  arrived,
  pickedUp,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case RideStatus.created: return 'Đang tìm tài xế';
      case RideStatus.driverAssigned: return 'Tài xế đã nhận';
      case RideStatus.arriving: return 'Đang đến đón';
      case RideStatus.arrived: return 'Đã đến điểm đón';
      case RideStatus.pickedUp: return 'Đã đón khách';
      case RideStatus.inProgress: return 'Đang di chuyển';
      case RideStatus.completed: return 'Hoàn thành';
      case RideStatus.cancelled: return 'Đã hủy';
    }
  }
}

enum ServiceType {
  ride,
  foodDelivery,
  grocery,
  designatedDriver;

  String get displayName {
    switch (this) {
      case ServiceType.ride: return 'Chở khách';
      case ServiceType.foodDelivery: return 'Giao đồ ăn';
      case ServiceType.grocery: return 'Đi chợ hộ';
      case ServiceType.designatedDriver: return 'Lái xe hộ';
    }
  }

  String get icon {
    switch (this) {
      case ServiceType.ride: return '🚗';
      case ServiceType.foodDelivery: return '🍔';
      case ServiceType.grocery: return '🛒';
      case ServiceType.designatedDriver: return '🚙';
    }
  }
}

enum VehicleType {
  bike,
  car,
  premium;

  String get displayName {
    switch (this) {
      case VehicleType.bike: return 'Xe máy';
      case VehicleType.car: return 'Ô tô';
      case VehicleType.premium: return 'Premium';
    }
  }

  String get icon {
    switch (this) {
      case VehicleType.bike: return '🏍️';
      case VehicleType.car: return '🚗';
      case VehicleType.premium: return '🚙';
    }
  }
}

class RideModel {
  final String id;
  final ServiceType serviceType;
  final RideStatus status;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final int durationMin;
  final double fareEstimate;
  final double? fareFinal;
  final String paymentMethod;
  final VehicleType vehicleType;
  final DriverModel? driver;
  final String? notes;
  final DateTime createdAt;

  RideModel({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.durationMin,
    required this.fareEstimate,
    this.fareFinal,
    required this.paymentMethod,
    required this.vehicleType,
    this.driver,
    this.notes,
    required this.createdAt,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] ?? '',
      serviceType: ServiceType.ride,
      status: _parseStatus(json['status']),
      pickupAddress: json['pickup_address'] ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: json['dropoff_address'] ?? '',
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      fareEstimate: (json['fare_estimate'] as num?)?.toDouble() ?? 0,
      fareFinal: (json['fare_final'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] ?? 'cash',
      vehicleType: VehicleType.car,
      driver: json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  static RideStatus _parseStatus(String? s) {
    switch (s) {
      case 'driver_assigned': return RideStatus.driverAssigned;
      case 'arriving': return RideStatus.arriving;
      case 'arrived': return RideStatus.arrived;
      case 'picked_up': return RideStatus.pickedUp;
      case 'in_progress': return RideStatus.inProgress;
      case 'completed': return RideStatus.completed;
      case 'cancelled': return RideStatus.cancelled;
      default: return RideStatus.created;
    }
  }
}
