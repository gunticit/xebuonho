import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _loading = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  bool get loading => _loading;
  String? get error => _error;
  double get lat => _currentPosition?.latitude ?? 10.7769;
  double get lng => _currentPosition?.longitude ?? 106.7009;

  Future<void> fetchLocation() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPosition = await LocationService.getCurrentLocation();
      if (_currentPosition == null) {
        _error = 'Không thể lấy vị trí. Hãy bật GPS.';
      }
    } catch (e) {
      _error = 'Lỗi GPS: $e';
    }

    _loading = false;
    notifyListeners();
  }
}
