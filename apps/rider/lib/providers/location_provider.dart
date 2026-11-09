import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  String _currentAddress = 'Đang định vị...';
  String _shortAddress = 'Buôn Hồ';
  bool _loading = false;
  String? _error;
  StreamSubscription<Position>? _positionSubscription;
  double _lastGeocodedLat = 0;
  double _lastGeocodedLng = 0;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  String get shortAddress => _shortAddress;
  bool get loading => _loading;
  String? get error => _error;

  // Defaults to Buôn Hồ, Đắk Lắk (12.9247, 108.2541)
  double get lat => _currentPosition?.latitude ?? LocationService.defaultLat;
  double get lng => _currentPosition?.longitude ?? LocationService.defaultLng;

  LocationProvider() {
    fetchLocation();
  }

  Future<void> fetchLocation() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPosition = await LocationService.getCurrentLocation();
      if (_currentPosition == null) {
        _currentAddress = LocationService.defaultAddress;
        _shortAddress = 'Buôn Hồ';
        _error = 'Chưa bật GPS, dùng vị trí mặc định.';
      } else {
        await _resolveAddress(_currentPosition!.latitude, _currentPosition!.longitude);
      }
      _startLiveTracking();
    } catch (e) {
      _error = 'Lỗi GPS: $e';
      _currentAddress = LocationService.defaultAddress;
      _shortAddress = 'Buôn Hồ';
    }

    _loading = false;
    notifyListeners();
  }

  void _startLiveTracking() {
    _positionSubscription?.cancel();
    try {
      _positionSubscription = LocationService.getLocationStream().listen(
        (Position position) {
          _currentPosition = position;
          // Re-reverse geocode if moved > 50m or first time
          final distKm = LocationService.distanceBetween(
            _lastGeocodedLat,
            _lastGeocodedLng,
            position.latitude,
            position.longitude,
          );
          if (distKm > 0.05 || _currentAddress == 'Đang định vị...') {
            _resolveAddress(position.latitude, position.longitude);
          } else {
            notifyListeners();
          }
        },
        onError: (err) {
          debugPrint('Location stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Error starting live tracking: $e');
    }
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    _lastGeocodedLat = lat;
    _lastGeocodedLng = lng;
    final addr = await LocationService.reverseGeocode(lat, lng);
    _currentAddress = addr;
    final parts = addr.split(',');
    if (parts.length >= 2) {
      _shortAddress = '${parts[0].trim()}, ${parts[1].trim()}';
    } else {
      _shortAddress = addr;
    }
    notifyListeners();
  }

  void setManualLocation({
    required double lat,
    required double lng,
    required String address,
  }) {
    _currentAddress = address;
    _shortAddress = address.split(',').first.trim();
    _currentPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
