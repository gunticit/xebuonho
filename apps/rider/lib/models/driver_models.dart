import 'ride.dart';

enum DriverStatus {
  offline,
  online,
  busy;

  String get displayName {
    switch (this) {
      case DriverStatus.offline:
        return 'Nghỉ ngơi';
      case DriverStatus.online:
        return 'Sẵn sàng nhận cuốc';
      case DriverStatus.busy:
        return 'Đang trong chuyến';
    }
  }
}

enum DriverTripStatus {
  accepted,
  arrivingPickup,
  arrivedPickup,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case DriverTripStatus.accepted:
        return 'Đã nhận cuốc';
      case DriverTripStatus.arrivingPickup:
        return 'Đang tới điểm đón';
      case DriverTripStatus.arrivedPickup:
        return 'Đã tới điểm đón';
      case DriverTripStatus.inProgress:
        return 'Đang di chuyển cùng khách';
      case DriverTripStatus.completed:
        return 'Hoàn thành';
      case DriverTripStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

class DriverRideRequest {
  final String id;
  final String riderName;
  final String riderPhone;
  final double riderRating;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final int durationMin;
  final double fare;
  final double driverEarning; // 80% sau trừ chiết khấu
  final ServiceType serviceType;
  final VehicleType vehicleType;
  final String paymentMethod;
  final String? notes;
  final DateTime createdAt;

  DriverRideRequest({
    required this.id,
    required this.riderName,
    required this.riderPhone,
    this.riderRating = 4.9,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    double? driverEarning,
    this.serviceType = ServiceType.ride,
    this.vehicleType = VehicleType.car,
    this.paymentMethod = 'cash',
    this.notes,
    DateTime? createdAt,
  })  : driverEarning = driverEarning ?? (fare * 0.8),
        createdAt = createdAt ?? DateTime.now();
}

class DriverTrip {
  final String id;
  final DriverRideRequest request;
  DriverTripStatus status;
  final DateTime startedAt;
  DateTime? completedAt;

  DriverTrip({
    required this.id,
    required this.request,
    this.status = DriverTripStatus.accepted,
    DateTime? startedAt,
    this.completedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}

class DriverDailyStats {
  final double todayEarnings;
  final int tripsCompleted;
  final int onlineMinutes;
  final double acceptanceRate;
  final double rating;

  const DriverDailyStats({
    this.todayEarnings = 385000,
    this.tripsCompleted = 5,
    this.onlineMinutes = 225,
    this.acceptanceRate = 96.5,
    this.rating = 4.92,
  });

  DriverDailyStats copyWith({
    double? todayEarnings,
    int? tripsCompleted,
    int? onlineMinutes,
    double? acceptanceRate,
    double? rating,
  }) {
    return DriverDailyStats(
      todayEarnings: todayEarnings ?? this.todayEarnings,
      tripsCompleted: tripsCompleted ?? this.tripsCompleted,
      onlineMinutes: onlineMinutes ?? this.onlineMinutes,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      rating: rating ?? this.rating,
    );
  }
}
