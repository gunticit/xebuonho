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

  // Trips (history & ratings via trip-service)
  static const String trips = '$apiVersion/trips';
  static String tripDetail(String id) => '$apiVersion/trips/$id';
  static String tripRating(String id) => '$apiVersion/trips/$id/rating';
  static String driverRatingSummary(String driverId) =>
      '$apiVersion/drivers/$driverId/rating-summary';

  // Driver tracking
  static const String driverLocation = '$apiVersion/driver/location/nearby';

  // Health
  static const String health = '/health';

  // Map & Location Services
  static const String reverseGeocode = '$apiVersion/maps/reverse-geocode';
  static const String route = '$apiVersion/maps/route';
  static const String searchPlaces = '$apiVersion/maps/search';
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

  // Reliable High-Speed Raster Basemap (Zero watermark, No key required)
  // Primary: Esri World Dark Gray Canvas (Sleek dark theme, zero watermark, 100% clean)
  static const String mapTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String mapTileLabelsUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';

  // Standard OpenStreetMap (Full color, zero watermark)
  static const String mapTileOsmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Universal Fallback Basemap
  static const String mapTileFallbackUrl = mapTileOsmUrl;
}
