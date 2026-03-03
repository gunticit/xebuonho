import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String _userName = 'Khách';
  String _userPhone = '';
  bool _isLoggedIn = false;

  String? get token => _token;
  String get userName => _userName;
  String get userPhone => _userPhone;
  bool get isLoggedIn => _isLoggedIn;

  void login({required String name, required String phone, required String token}) {
    _userName = name;
    _userPhone = phone;
    _token = token;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _token = null;
    _userName = 'Khách';
    _userPhone = '';
    _isLoggedIn = false;
    notifyListeners();
  }

  // Quick login for demo
  void demoLogin() {
    login(
      name: 'Nguyễn Văn An',
      phone: '0901234567',
      token: 'demo-token-xebuonho',
    );
  }
}
