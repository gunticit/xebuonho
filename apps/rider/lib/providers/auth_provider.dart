import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  String _userId = '';
  String _userName = 'Khách';
  String _userPhone = '';
  String _userEmail = '';
  String _userRole = 'rider';
  String _vehicleType = 'car';
  String _licensePlate = '59-A1 999.88';
  String _vehicleModel = 'Toyota Vios 2023';
  String _driverKind = 'personal'; // personal | business
  String _approvalStatus = 'approved';
  String? _rejectionReason;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _needsOtp = false;
  String? _error;

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String get userId => _userId;
  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userEmail => _userEmail;
  String get userRole => _userRole;
  String get vehicleType => _vehicleType;
  String get licensePlate => _licensePlate;
  String get vehicleModel => _vehicleModel;
  String get driverKind => _driverKind;
  bool get isBusinessDriver => isDriver && _driverKind == 'business';
  String get approvalStatus => _approvalStatus;
  String? get rejectionReason => _rejectionReason;
  bool get isDriver => _userRole == 'driver';
  bool get isAdmin => _userRole == 'admin';
  bool get isDriverApproved => !isDriver || _approvalStatus == 'approved';
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get needsOtp => _needsOtp;
  String? get error => _error;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.authBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // ==========================================
  // Register
  // ==========================================
  Future<bool> register({
    required String phone,
    required String password,
    required String fullName,
    String role = 'rider',
    String driverKind = 'personal',
    bool consentAccepted = false,
    String consentVersion = '2026.1',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post(ApiConfig.register, data: {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'role': role,
        if (role == 'driver') 'driver_kind': driverKind,
        'consent_accepted': consentAccepted,
        'consent_version': consentVersion,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _setFromResponse(response.data);
        _userPhone = phone;
        _userName = fullName;
        _needsOtp = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        // Server unavailable → use demo/offline mode
        debugPrint('⚠️ Server không chạy → đăng ký offline mode');
        _registerOffline(fullName, phone, role: role, driverKind: driverKind);
        return true;
      }
      _error = e.response?.data?['error'] ?? 'Đăng ký thất bại';
    } catch (e) {
      debugPrint('⚠️ Register error: $e → fallback offline');
      _registerOffline(fullName, phone, role: role, driverKind: driverKind);
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void _registerOffline(String name, String phone, {String role = 'rider', String driverKind = 'personal'}) {
    _userId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    _userName = name;
    _userPhone = phone;
    _userRole = role;
    _driverKind = driverKind;
    _token = 'offline-token';
    _isLoggedIn = true;
    _needsOtp = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // ==========================================
  // Verify OTP
  // ==========================================
  Future<bool> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Demo code always works (offline or online)
    if (code == '123456') {
      _needsOtp = false;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    try {
      final response = await _dio.post(ApiConfig.verifyOtp, data: {
        'phone': _userPhone,
        'code': code,
      });

      if (response.statusCode == 200) {
        _needsOtp = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _error = 'Nhập mã 123456 để demo';
      } else {
        _error = e.response?.data?['error'] ?? 'Mã OTP không đúng';
      }
    } catch (_) {
      _error = 'Nhập mã 123456 để demo';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // ==========================================
  // Resend OTP
  // ==========================================
  Future<bool> resendOtp() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dio.post(ApiConfig.resendOtp, data: {
        'phone': _userPhone,
      });
    } catch (_) {
      // OK silently if server not running
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ==========================================
  // Login
  // ==========================================
  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post(ApiConfig.login, data: {
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        _setFromResponse(response.data);
        _needsOtp = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        // Server unavailable → demo login
        debugPrint('⚠️ Server không chạy → đăng nhập demo mode');
        _loginOffline(phone);
        return true;
      }
      _error = e.response?.data?['error'] ?? 'Sai số điện thoại hoặc mật khẩu';
    } catch (e) {
      debugPrint('⚠️ Login error: $e → fallback offline');
      _loginOffline(phone);
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void _loginOffline(String phone) {
    _userId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    _userName = 'Người dùng';
    _userPhone = phone;
    _userRole = 'rider';
    _token = 'offline-token';
    _isLoggedIn = true;
    _needsOtp = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // ==========================================
  // Refresh token
  // ==========================================
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await _dio.post(ApiConfig.refresh, data: {
        'refresh_token': _refreshToken,
      });
      if (response.statusCode == 200) {
        _setFromResponse(response.data);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ==========================================
  // Logout & Demo
  // ==========================================
  void logout() {
    _token = null;
    _refreshToken = null;
    _userId = '';
    _userName = 'Khách';
    _userPhone = '';
    _userEmail = '';
    _isLoggedIn = false;
    _needsOtp = false;
    _error = null;
    NotificationService().disconnect();
    notifyListeners();
  }

  Future<void> demoLogin({String role = 'rider'}) async {
    _isLoading = true;
    notifyListeners();

    final String phone;
    final String password;
    switch (role) {
      case 'driver':
        phone = '0912345678';
        password = 'secret123';
        break;
      case 'admin':
        phone = '0900000001';
        password = 'admin123';
        break;
      default:
        phone = '0901234567';
        password = 'password123';
    }

    try {
      final success = await login(phone: phone, password: password);
      if (success) {
        _userRole = role;
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (_) {}

    // Fallback if offline
    _userId = 'demo-$role';
    _userRole = role;
    if (role == 'driver') {
      _userName = 'Nguyễn Văn Tài (Tài Xế)';
      _userPhone = '0912 345 678';
      _userEmail = 'taixe@xebuonho.vn';
      _vehicleType = 'car';
      _licensePlate = '59-E1 888.66';
      _vehicleModel = 'Toyota Vios 2023';
    } else if (role == 'admin') {
      _userName = 'Quản trị viên';
      _userPhone = '0900 000 001';
      _userEmail = 'admin@xebuonho.vn';
      _approvalStatus = 'approved';
    } else {
      _userName = 'Nguyễn Văn An';
      _userPhone = '0901 234 567';
      _userEmail = 'an@xebuonho.vn';
    }
    _token = 'demo-token';
    _isLoggedIn = true;
    _needsOtp = false;
    _isLoading = false;
    notifyListeners();
  }

  void switchRole(String newRole) {
    _userRole = newRole;
    if (_userRole == 'driver' && _licensePlate.isEmpty) {
      _licensePlate = '59-E1 888.66';
      _vehicleModel = 'Toyota Vios 2023';
      _vehicleType = 'car';
    }
    notifyListeners();
  }

  void skipOtp() {
    _needsOtp = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================
  // Helpers
  // ==========================================
  bool _isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.unknown;
  }

  void _setFromResponse(Map<String, dynamic> data) {
    _token = data['access_token'];
    _refreshToken = data['refresh_token'];
    _isLoggedIn = true;
    _error = null;

    if (_token != null && _token!.isNotEmpty) {
      ApiService().setAuthToken(_token!);
      // Realtime push: nhận ride_accepted / ride_status_updated tức thời
      NotificationService().connect(_token!);
    }

    final user = data['user'];
    if (user != null) {
      _userId = user['id'] ?? '';
      _userName = user['full_name'] ?? 'Người dùng';
      _userPhone = user['phone'] ?? '';
      _userEmail = user['email'] ?? '';
      _userRole = user['role'] ?? 'rider';
      _driverKind = user['driver_kind'] ?? 'personal';
      if (user['vehicle_type'] != null) {
        _vehicleType = user['vehicle_type'];
      }
      if (user['license_plate'] != null) {
        _licensePlate = user['license_plate'];
      }
      if (user['vehicle_model'] != null) {
        _vehicleModel = user['vehicle_model'];
      }
      if (user['approval_status'] != null) {
        _approvalStatus = user['approval_status'];
      } else {
        _approvalStatus = _userRole == 'driver' ? 'pending_approval' : 'approved';
      }
      _rejectionReason = user['rejection_reason'];
    }
  }

  void setApprovalStatus(String status, {String? reason}) {
    _approvalStatus = status;
    _rejectionReason = reason;
    notifyListeners();
  }

  void updateDriverKYC({
    required String vehicleType,
    required String licensePlate,
    required String vehicleModel,
  }) {
    _vehicleType = vehicleType;
    _licensePlate = licensePlate;
    _vehicleModel = vehicleModel;
    _approvalStatus = 'pending_approval';
    notifyListeners();
  }
}
