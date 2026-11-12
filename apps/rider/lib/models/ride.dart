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
  designatedDriver,
  expressDelivery;

  String get displayName {
    switch (this) {
      case ServiceType.ride: return 'Chở khách';
      case ServiceType.foodDelivery: return 'Giao đồ ăn';
      case ServiceType.grocery: return 'Đi chợ hộ';
      case ServiceType.designatedDriver: return 'Lái xe hộ';
      case ServiceType.expressDelivery: return 'Giao hàng';
    }
  }

  String get icon {
    switch (this) {
      case ServiceType.ride: return '🚗';
      case ServiceType.foodDelivery: return '🍔';
      case ServiceType.grocery: return '🛒';
      case ServiceType.designatedDriver: return '🚙';
      case ServiceType.expressDelivery: return '📦';
    }
  }

  static ServiceType fromString(String? val) {
    switch (val) {
      case 'food_delivery':
      case 'food':
        return ServiceType.foodDelivery;
      case 'grocery':
        return ServiceType.grocery;
      case 'designated_driver':
      case 'designated':
        return ServiceType.designatedDriver;
      case 'express_delivery':
      case 'express':
        return ServiceType.expressDelivery;
      default:
        return ServiceType.ride;
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

  /// Accepts either the ride object directly or the API envelope `{"ride": {...}}`.
  factory RideModel.fromJson(Map<String, dynamic> json) {
    final d = (json['ride'] is Map<String, dynamic>)
        ? json['ride'] as Map<String, dynamic>
        : json;
    return RideModel(
      id: d['id']?.toString() ?? '',
      serviceType: ServiceType.fromString(d['service_type']?.toString()),
      status: _parseStatus(d['status']?.toString()),
      pickupAddress: d['pickup_address'] ?? '',
      pickupLat: (d['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (d['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: d['dropoff_address'] ?? '',
      dropoffLat: (d['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (d['dropoff_lng'] as num?)?.toDouble() ?? 0,
      distanceKm: (d['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (d['duration_minutes'] as num?)?.toInt() ??
          (d['duration_min'] as num?)?.toInt() ?? 0,
      fareEstimate: (d['fare_estimate'] as num?)?.toDouble() ?? 0,
      fareFinal: (d['fare_final'] as num?)?.toDouble(),
      paymentMethod: d['payment_method'] ?? 'cash',
      vehicleType: _parseVehicle(d['vehicle_type']?.toString()),
      driver: d['driver'] is Map<String, dynamic>
          ? DriverModel.fromJson(d['driver'] as Map<String, dynamic>)
          : null,
      notes: d['notes'],
      createdAt: DateTime.tryParse(d['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  static VehicleType _parseVehicle(String? s) {
    switch (s) {
      case 'motorcycle':
      case 'bike':
        return VehicleType.bike;
      case 'premium':
        return VehicleType.premium;
      default:
        return VehicleType.car;
    }
  }

  /// Gateway FSM statuses: accepted | arriving | arrived | in_progress |
  /// completed | cancelled | scheduled | created.
  static RideStatus _parseStatus(String? s) {
    switch (s) {
      case 'accepted':
      case 'driver_assigned':
        return RideStatus.driverAssigned;
      case 'arriving': return RideStatus.arriving;
      case 'arrived': return RideStatus.arrived;
      case 'picked_up': return RideStatus.pickedUp;
      case 'in_progress': return RideStatus.inProgress;
      case 'completed': return RideStatus.completed;
      case 'cancelled': return RideStatus.cancelled;
      default: return RideStatus.created; // created + scheduled
    }
  }
}
