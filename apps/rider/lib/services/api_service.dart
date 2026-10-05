import 'dart:math';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  static String? _authToken;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor: inject Authorization token automatically
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null && _authToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  void setAuthToken(String token) {
    _authToken = token;
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
    final idempotencyKey = 'ride-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

    final res = await _dio.post(
      ApiConfig.createRide,
      options: Options(
        headers: {
          'X-Idempotency-Key': idempotencyKey,
        },
      ),
      data: {
        'pickup_address': pickupAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_address': dropoffAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'vehicle_type': vehicleType,
        'payment_method': paymentMethod,
        'notes': notes,
      },
    );
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

  // ========== Real Merchants & Menu from PostgreSQL ==========
  Future<List<Map<String, dynamic>>> getNearbyMerchants({
    required double lat,
    required double lng,
    double radius = 10.0,
    String? category,
  }) async {
    final res = await _dio.get(ApiConfig.nearbyMerchants, queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius': radius,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    final merchants = res.data['merchants'] as List? ?? [];
    return merchants.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMerchantMenu(String merchantId) async {
    final res = await _dio.get('${ApiConfig.baseUrl}/api/v1/merchants/$merchantId/menu');
    final items = res.data['items'] as List? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  // ========== Driver API (PostgreSQL Connected) ==========
  Future<bool> toggleDriverOnline() async {
    try {
      final res = await _dio.post('${ApiConfig.baseUrl}/api/v1/driver/toggle');
      return res.data['online'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> getDriverRequests() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/v1/driver/requests');
      final requests = res.data['requests'] as List? ?? [];
      return requests.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> acceptDriverRequest(String requestId) async {
    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}/api/v1/driver/accept',
        data: {'request_id': requestId},
      );
      return res.data['accepted'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> updateDriverTripStatus(String requestId, String action) async {
    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}/api/v1/driver/trip/update',
        data: {
          'request_id': requestId,
          'action': action,
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
