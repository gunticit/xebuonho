class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = '/api/v1';

  // Rides
  static const String estimateFare = '$apiVersion/rides/estimate';
  static const String createRide = '$apiVersion/rides';
  static String rideDetail(String id) => '$apiVersion/rides/$id';

  // Merchants
  static const String nearbyMerchants = '$apiVersion/merchants/nearby';
  static const String searchMerchants = '$apiVersion/merchants/search';

  // Driver tracking
  static const String driverLocation = '$apiVersion/driver/location/nearby';

  // Health
  static const String health = '/health';
}
