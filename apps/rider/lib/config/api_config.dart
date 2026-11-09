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

  // Map & Location Services
  // Amazon Location Service
  static const String awsLocationApiKey =
      'v1.public.eyJqdGkiOiI3ZjBmMzJhMi0yZWYxLTQyN2QtODAyOC04ZjQwNTlhNTQ2Y2IifZbUjXu17vZU5uBpfs62teNiNDc-WYEdXeWNGaAN7jnqD8FSQ7e8w7okGLwwT-gy2TUJ5tQuwn6RFPZyQv_0RXRWLkwasBR9dCBuln-_B5xJrwzR_YJp4DK84sJEFonix3AzFY2Mxnd5VER_5WDtMOfdw6ZMAXb03aXDRsolFTb9z4mMxE9C82D2DcjJHL2Ns6flA3aSWqHByYD4XM5I2RB9sUdBoFmZpczC-q93tb0d-GFTjrsSadPJpLmA3TcR3O377qQMWmTgykCgASkcV40BwL2vgWrv-qdSTApV0MgGGMYB_pGk53RF0tBv1B_SYITt7Axh2ru6cSD1N0l8lwo.ZTA2OTdiZTItNzgyYy00YWI5LWFmODQtZjdkYmJkODNkMmFh';
  static const String awsLocationRegion = 'ap-southeast-2';
  static const String awsLocationMapName = 'explore.map';
  static const String awsLocationPlaceIndex = 'explore.place';
  static const String awsLocationRouteCalculator = 'explore.route';

  static const String awsLocationMapTileUrl =
      'https://maps.geo.$awsLocationRegion.amazonaws.com/maps/v0/maps/$awsLocationMapName/tiles/{z}/{x}/{y}?key=$awsLocationApiKey';
  static const String awsLocationPlacesSearchUrl =
      'https://places.geo.$awsLocationRegion.amazonaws.com/places/v0/indexes/$awsLocationPlaceIndex/search/text';
  static const String awsLocationRouteUrl =
      'https://routes.geo.$awsLocationRegion.amazonaws.com/routes/v0/calculators/$awsLocationRouteCalculator/calculate/route';

  // CARTO Basemap (Alternative / Fallback)
  static const String cartoApiKey =
      'eyJhbGciOiJIUzI1NiJ9.eyJhIjoiYWNfMWkwYXkwZzYiLCJqdGkiOiJlMGUyM2U0ZjM1Mjg3YWU5M2RjMDNhMDU2N2U3ZWMyYiJ9.s8qzAxKP60NXuZ9SLc6dGyfKs7HHXK0NUmw7EEAveTE';
  static const String mapTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png?api_key=$cartoApiKey';
}
