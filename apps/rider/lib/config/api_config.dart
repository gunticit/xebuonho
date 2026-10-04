class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  // Auth calls go directly to user-service to bypass gateway auth middleware
  static const String authBaseUrl = 'http://localhost:8091';
  static const String apiVersion = '/api/v1';

  // Auth
  static const String register = '$apiVersion/auth/register';
  static const String login = '$apiVersion/auth/login';
  static const String refresh = '$apiVersion/auth/refresh';
  static const String logout = '$apiVersion/auth/logout';
  static const String profile = '$apiVersion/auth/profile';
  static const String verifyOtp = '$apiVersion/auth/verify-otp';
  static const String resendOtp = '$apiVersion/auth/resend-otp';

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

  // Map (CARTO Basemap)
  static const String cartoApiKey =
      'eyJhbGciOiJIUzI1NiJ9.eyJhIjoiYWNfMWkwYXkwZzYiLCJqdGkiOiJlMGUyM2U0ZjM1Mjg3YWU5M2RjMDNhMDU2N2U3ZWMyYiJ9.s8qzAxKP60NXuZ9SLc6dGyfKs7HHXK0NUmw7EEAveTE';
  static const String mapTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png?api_key=$cartoApiKey';
}
