import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  String _userId = '';
  String _userName = 'Khách';
  String _userPhone = '';
  String _userEmail = '';
  String _userRole = 'rider';
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
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get needsOtp => _needsOtp;
  String? get error => _error;

  // Auth calls go directly to user-service
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Register a new user → returns true = needs OTP verification
  Future<bool> register({
    required String phone,
    required String password,
    required String fullName,
    String role = 'rider',
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
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _setFromResponse(response.data);
        _userPhone = phone;
        _needsOtp = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Đăng ký thất bại. Thử lại sau.';
    } catch (e) {
      _error = 'Không kết nối được server. Kiểm tra kết nối mạng.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Verify OTP code
  Future<bool> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

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
      _error = e.response?.data?['error'] ?? 'Mã OTP không đúng';
    } catch (e) {
      _error = 'Lỗi kết nối';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Resend OTP
  Future<bool> resendOtp() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dio.post(ApiConfig.resendOtp, data: {
        'phone': _userPhone,
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Không gửi được mã OTP';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Login
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
      _error = e.response?.data?['error'] ?? 'Sai số điện thoại hoặc mật khẩu';
    } catch (e) {
      _error = 'Không kết nối được server';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Refresh token
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

  /// Logout
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
    notifyListeners();
  }

  /// Demo login (skip server)
  void demoLogin() {
    _userId = 'demo-user';
    _userName = 'Nguyễn Văn An';
    _userPhone = '0901234567';
    _userEmail = 'an@xebuonho.vn';
    _userRole = 'rider';
    _token = 'demo-token';
    _isLoggedIn = true;
    _needsOtp = false;
    notifyListeners();
  }

  /// Skip OTP (for demo)
  void skipOtp() {
    _needsOtp = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setFromResponse(Map<String, dynamic> data) {
    _token = data['access_token'];
    _refreshToken = data['refresh_token'];
    _isLoggedIn = true;
    _error = null;

    final user = data['user'];
    if (user != null) {
      _userId = user['id'] ?? '';
      _userName = user['full_name'] ?? 'Người dùng';
      _userPhone = user['phone'] ?? '';
      _userEmail = user['email'] ?? '';
      _userRole = user['role'] ?? 'rider';
    }
  }
}
