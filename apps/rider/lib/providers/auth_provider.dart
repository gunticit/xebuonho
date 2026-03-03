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
  String? get error => _error;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Register a new user
  Future<bool> register({
    required String phone,
    required String password,
    required String fullName,
    String role = 'rider',
    String email = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post('/api/v1/auth/register', data: {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'role': role,
        if (email.isNotEmpty) 'email': email,
      });

      if (response.statusCode == 201) {
        _setFromResponse(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Đăng ký thất bại';
    } catch (e) {
      _error = 'Lỗi kết nối: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Login with phone + password
  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200) {
        _setFromResponse(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['error'] ?? 'Đăng nhập thất bại';
    } catch (e) {
      _error = 'Lỗi kết nối server';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Refresh the access token
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _dio.post('/api/v1/auth/refresh', data: {
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
    _error = null;
    notifyListeners();
  }

  /// Quick login for demo (when server is not available)
  void demoLogin() {
    _userId = 'demo-user';
    _userName = 'Nguyễn Văn An';
    _userPhone = '0901234567';
    _userEmail = 'an@xebuonho.vn';
    _userRole = 'rider';
    _token = 'demo-token';
    _isLoggedIn = true;
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
