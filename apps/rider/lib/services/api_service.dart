import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ========== Health ==========
  Future<bool> healthCheck() async {
    try {
      final res = await _dio.get(ApiConfig.health);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ========== Rides ==========
  Future<Map<String, dynamic>> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String vehicleType,
  }) async {
    final res = await _dio.post(ApiConfig.estimateFare, data: {
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'vehicle_type': vehicleType,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> createRide({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String vehicleType,
    required String paymentMethod,
    String? notes,
  }) async {
    final res = await _dio.post(ApiConfig.createRide, data: {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'vehicle_type': vehicleType,
      'payment_method': paymentMethod,
      'notes': notes,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getRide(String id) async {
    final res = await _dio.get(ApiConfig.rideDetail(id));
    return res.data;
  }

  // ========== Nearby Drivers ==========
  Future<List<Map<String, dynamic>>> getNearbyDrivers() async {
    final res = await _dio.get(ApiConfig.driverLocation);
    final drivers = res.data['drivers'] as List;
    return drivers.cast<Map<String, dynamic>>();
  }

  // ========== Merchants ==========
  Future<List<Map<String, dynamic>>> getNearbyMerchants({
    required double lat,
    required double lng,
    double radius = 3.0,
  }) async {
    final res = await _dio.get(ApiConfig.nearbyMerchants, queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius': radius,
    });
    final merchants = res.data['merchants'] as List?;
    return merchants?.cast<Map<String, dynamic>>() ?? [];
  }
}
