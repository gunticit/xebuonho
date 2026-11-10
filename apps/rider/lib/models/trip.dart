/// Trip — một chuyến đã kết thúc (hoàn thành / đã hủy), đọc từ trip-service.
/// Áp cho cả 4 loại dịch vụ: ride, food_delivery, grocery, designated_driver.
class TripModel {
  final String id;
  final String serviceType;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final String vehicleType;
  final String driverName;
  final String driverVehicle;
  final double fareEstimate;
  final double? fareFinal;
  final double? distanceKm;
  final int? durationMin;
  final String paymentMethod;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Đánh giá của khách cho chuyến này (null = chưa đánh giá)
  final int? rating;
  final double? tipAmount;
  final String? comment;

  TripModel({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.vehicleType,
    required this.driverName,
    required this.driverVehicle,
    required this.fareEstimate,
    this.fareFinal,
    this.distanceKm,
    this.durationMin,
    required this.paymentMethod,
    this.cancelledBy,
    required this.createdAt,
    this.completedAt,
    this.rating,
    this.tipAmount,
    this.comment,
  });

  bool get isCancelled => status.startsWith('cancelled') || status == 'merchant_rejected';

  double get displayFare => fareFinal ?? fareEstimate;

  DateTime get displayTime => completedAt ?? createdAt;

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] ?? '',
      serviceType: json['service_type'] ?? 'ride',
      status: json['status'] ?? 'completed',
      pickupAddress: json['pickup_address'] ?? '',
      dropoffAddress: json['dropoff_address'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      driverName: json['driver_name'] ?? '',
      driverVehicle: json['driver_vehicle'] ?? '',
      fareEstimate: (json['fare_estimate'] as num?)?.toDouble() ?? 0,
      fareFinal: (json['fare_final'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMin: json['duration_min'] as int?,
      paymentMethod: json['payment_method'] ?? 'cash',
      cancelledBy: json['cancelled_by'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      rating: json['rating'] as int?,
      tipAmount: (json['tip_amount'] as num?)?.toDouble(),
      comment: json['comment'],
    );
  }
}
