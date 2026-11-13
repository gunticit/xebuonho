import 'dart:typed_data';
import 'dart:math';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// Lỗi API có message rõ ràng (lấy từ response `error` của server nếu có).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  static ApiException fromDio(DioException e) {
    final data = e.response?.data;
    final msg = data is Map && data['error'] != null
        ? data['error'].toString()
        : (data is Map && data['message'] != null ? data['message'].toString() : null);
    if (msg != null && msg.isNotEmpty) return ApiException(msg, statusCode: e.response?.statusCode);
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException('Không kết nối được server. Kiểm tra backend đang chạy.');
      default:
        return ApiException('Lỗi kết nối: ${e.message ?? e.type.name}');
    }
  }
}

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

  // ========== Driver KYC & Compliance ==========
  Future<Response> submitDriverKYC(Map<String, dynamic> data) async {
    return await _dio.post(
      '${ApiConfig.authBaseUrl}${ApiConfig.driverKYC}',
      data: data,
    );
  }

  /// Hồ sơ KYC đã nộp của chính tài xế (fields + ảnh presigned GET)
  Future<Map<String, dynamic>> getMyKyc() async {
    final res = await _dio.get('${ApiConfig.authBaseUrl}${ApiConfig.driverKYC}');
    return res.data as Map<String, dynamic>;
  }

  /// Ask user-service for a presigned MinIO PUT URL, then upload the bytes
  /// directly to object storage. Returns the object key to embed in the KYC payload.
  /// Dùng Uint8List (không dart:io) để chạy được trên cả Web lẫn Mobile.
  Future<String> uploadKycDocument({
    required String docType,
    required Uint8List bytes,
    required String fileExt,
    void Function(int sent, int total)? onProgress,
  }) async {
    final contentType = _contentTypeForExt(fileExt);

    final presignRes = await _dio.post(
      '${ApiConfig.authBaseUrl}${ApiConfig.uploadsPresign}',
      data: {
        'doc_type': docType,
        'file_ext': fileExt,
        'content_type': contentType,
      },
    );

    final uploadUrl = presignRes.data['upload_url'] as String;
    final objectKey = presignRes.data['object_key'] as String;

    final uploadDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
    await uploadDio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
      ),
      onSendProgress: onProgress,
    );
    return objectKey;
  }

  static String _contentTypeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ========== Admin KYC Moderation ==========
  Future<List<Map<String, dynamic>>> adminListDrivers({
    String status = '',
    String kind = '',
  }) async {
    final res = await _dio.get(
      '${ApiConfig.authBaseUrl}${ApiConfig.adminDrivers}',
      queryParameters: {'status': status, 'kind': kind},
    );
    final drivers = res.data['drivers'] as List? ?? [];
    return drivers.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminDriverDetail(String driverId) async {
    final res = await _dio.get('${ApiConfig.authBaseUrl}${ApiConfig.adminDriverDetail(driverId)}');
    return res.data as Map<String, dynamic>;
  }

  Future<Response> adminSetApproval(String driverId, String status, {String reason = ''}) async {
    return await _dio.patch(
      '${ApiConfig.authBaseUrl}${ApiConfig.adminDriverApproval(driverId)}',
      data: {'status': status, 'reason': reason},
    );
  }

  // ========== Admin Analytics & Operations ==========
  Future<Map<String, dynamic>> adminGetStats() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}${ApiConfig.apiVersion}/admin/stats');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> adminGetRevenue() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}${ApiConfig.apiVersion}/admin/revenue');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> adminGetRecentOrders() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}${ApiConfig.apiVersion}/admin/orders/recent');
      final orders = res.data['orders'] as List? ?? [];
      return orders.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> adminGetNearbyDrivers() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}${ApiConfig.driverLocation}');
      final drivers = res.data['drivers'] as List? ?? [];
      return drivers.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
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
    String serviceType = 'ride',
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String vehicleType,
    required String paymentMethod,
    String? notes,
    String? scheduledAt, // RFC3339 hoặc 'YYYY-MM-DD HH:MM'
    String? designatedMode,
    String? designatedVehicleType,
    String? designatedLicensePlate,
  }) async {
    final idempotencyKey = 'ride-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

    try {
      final res = await _dio.post(
        ApiConfig.createRide,
        options: Options(
          headers: {
            'X-Idempotency-Key': idempotencyKey,
          },
        ),
        data: {
          'service_type': serviceType,
          'pickup_address': pickupAddress,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_address': dropoffAddress,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'vehicle_type': vehicleType,
          'payment_method': paymentMethod,
          'notes': notes,
          if (scheduledAt != null && scheduledAt.isNotEmpty) 'scheduled_at': scheduledAt,
          if (designatedMode != null && designatedMode.isNotEmpty) 'designated_mode': designatedMode,
          if (designatedVehicleType != null && designatedVehicleType.isNotEmpty)
            'designated_vehicle_type': designatedVehicleType,
          if (designatedLicensePlate != null && designatedLicensePlate.isNotEmpty)
            'designated_license_plate': designatedLicensePlate,
        },
      );
      return res.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getRide(String id) async {
    final res = await _dio.get(ApiConfig.rideDetail(id));
    return res.data;
  }

  /// Huỷ chuyến (chỉ chủ chuyến, khi status created/accepted).
  Future<void> cancelRide(String id, {String reason = ''}) async {
    try {
      await _dio.patch(
        '${ApiConfig.rideDetail(id)}/cancel',
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ========== Chat Khách ↔ Tài xế (order_messages) ==========
  Future<List<Map<String, dynamic>>> getRideMessages(String rideId) async {
    final res = await _dio.get('${ApiConfig.rideDetail(rideId)}/messages');
    final messages = res.data['messages'] as List? ?? [];
    return messages.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendRideMessage(String rideId, String message) async {
    try {
      final res = await _dio.post(
        '${ApiConfig.rideDetail(rideId)}/messages',
        data: {'message': message},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
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

  /// Nhận cuốc — trả null nếu thành công, ngược lại message lỗi
  /// (VD: 403 khi tài xế chưa được duyệt KYC, 409 khi cuốc đã có người nhận).
  Future<String?> acceptDriverRequest(String requestId) async {
    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}/api/v1/driver/accept',
        data: {'request_id': requestId},
      );
      return res.data['accepted'] == true ? null : 'Không nhận được cuốc';
    } on DioException catch (e) {
      return ApiException.fromDio(e).message;
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

  /// Gửi vị trí GPS tài xế lên server (rider tracking + nearby list đọc từ đây).
  Future<void> updateDriverLocation({
    required double lat,
    required double lng,
    double speed = 0,
    double heading = 0,
    int battery = 0,
  }) async {
    try {
      await _dio.post('${ApiConfig.baseUrl}/api/v1/driver/location/update', data: {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heading': heading,
        'battery': battery,
      });
    } catch (_) {
      // Location là best-effort — không chặn luồng tài xế
    }
  }

  /// Cuốc đang thực hiện của tài xế (sync sau reload / mỗi transition).
  Future<Map<String, dynamic>?> getCurrentDriverTrip() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/v1/driver/trip/current');
      final trip = res.data['trip'];
      return trip is Map<String, dynamic> ? trip : null;
    } catch (_) {
      return null;
    }
  }

  /// Tổng thu nhập thật từ orders completed (gateway /driver/earnings).
  Future<Map<String, dynamic>?> getDriverEarnings() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/v1/driver/earnings');
      return res.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Lịch sử chuyến thật của tài xế (gateway /driver/history).
  Future<List<Map<String, dynamic>>> getDriverHistory({int limit = 20}) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}/api/v1/driver/history',
        queryParameters: {'limit': limit},
      );
      final history = res.data['history'] as List? ?? [];
      return history.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ========== Trips — lịch sử chuyến & đánh giá (trip-service) ==========
  Future<List<Map<String, dynamic>>> getTripHistory({
    String role = 'rider',
    String? serviceType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(ApiConfig.trips, queryParameters: {
      'role': role,
      'page': page,
      'page_size': pageSize,
      if (serviceType != null && serviceType.isNotEmpty) 'service_type': serviceType,
    });
    final trips = res.data['trips'] as List? ?? [];
    return trips.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTripDetail(String id) async {
    final res = await _dio.get(ApiConfig.tripDetail(id));
    return res.data;
  }

  Future<Map<String, dynamic>> submitTripRating(
    String tripId, {
    required int rating,
    double tipAmount = 0,
    String comment = '',
  }) async {
    final res = await _dio.post(ApiConfig.tripRating(tripId), data: {
      'rating': rating,
      'tip_amount': tipAmount,
      'comment': comment,
    });
    return res.data;
  }
}
