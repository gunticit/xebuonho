class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String licensePlate;
  final String vehicleType;
  final String? vehicleModel;
  final double rating;
  final String? avatarUrl;
  final double? lat;
  final double? lng;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.licensePlate,
    required this.vehicleType,
    this.vehicleModel,
    required this.rating,
    this.avatarUrl,
    this.lat,
    this.lng,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      licensePlate: json['license_plate'] ?? '',
      vehicleType: json['vehicle_type'] ?? 'car',
      vehicleModel: json['vehicle_model'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      avatarUrl: json['avatar_url'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}
