import 'package:geolocator/geolocator.dart';
import 'geocoding_service.dart';

class LocationService {
  // XeBuonHo home market default coordinates
  static const double defaultLat = 12.9247;
  static const double defaultLng = 108.2541;
  static const String defaultAddress = 'Thị xã Buôn Hồ, Đắk Lắk';

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return await Geolocator.getLastKnownPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return await Geolocator.getLastKnownPosition();
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return await Geolocator.getLastKnownPosition();
      }

      // 1. Thử lấy GPS chính xác cao (High Accuracy) với timeout 10 giây
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      try {
        // 2. Dự phòng độ chính xác trung bình (Medium Accuracy) nếu High bị timeout
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        try {
          return await Geolocator.getLastKnownPosition();
        } catch (_) {
          return null;
        }
      }
    }
  }

  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // meters
      ),
    );
  }

  static Future<String> reverseGeocode(double lat, double lng) async {
    final geocoding = GeocodingService();
    try {
      final addr = await geocoding.reverseGeocode(lat, lng);
      if (addr != null && addr.isNotEmpty) {
        return addr;
      }
    } catch (_) {}

    // Regional heuristic fallback
    if (lat >= 12.80 && lat <= 13.15 && lng >= 108.10 && lng <= 108.45) {
      return lat > 12.95 ? 'Huyện Krông Búk, Đắk Lắk' : 'Thị xã Buôn Hồ, Đắk Lắk';
    } else if (lat >= 12.50 && lat <= 12.80 && lng >= 107.90 && lng <= 108.20) {
      return 'TP. Buôn Ma Thuột, Đắk Lắk';
    } else if (lat >= 10.60 && lat <= 10.95 && lng >= 106.50 && lng <= 106.90) {
      return 'TP. Hồ Chí Minh';
    }
    return defaultAddress;
  }

  static double distanceBetween(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000; // km
  }
}
