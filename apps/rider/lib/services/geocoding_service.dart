import 'dart:async';
import 'package:dio/dio.dart';

class GeocodingResult {
  final String name;
  final String displayName;
  final double lat;
  final double lng;
  final String type;

  GeocodingResult({
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lng,
    required this.type,
  });

  String get emoji {
    switch (type) {
      case 'aeroway':
        return '✈️';
      case 'hospital':
      case 'clinic':
        return '🏥';
      case 'school':
      case 'university':
        return '🎓';
      case 'restaurant':
      case 'cafe':
        return '🍔';
      case 'shop':
      case 'mall':
      case 'marketplace':
        return '🛍️';
      case 'hotel':
        return '🏨';
      case 'park':
      case 'garden':
        return '🌳';
      case 'place_of_worship':
        return '⛪';
      case 'bus_station':
      case 'station':
        return '🚉';
      default:
        return '📍';
    }
  }
}

/// Geocoding service using Nominatim (OpenStreetMap) - free, no API key needed
class GeocodingService {
  final Dio _dio;
  Timer? _debounceTimer;

  GeocodingService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://nominatim.openstreetmap.org',
          headers: {
            'User-Agent': 'XebuonhoRiderApp/1.0',
            'Accept-Language': 'vi',
          },
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));

  /// Search for addresses with debounce (400ms)
  Future<List<GeocodingResult>> search(String query,
      {double? lat, double? lng}) async {
    if (query.trim().length < 2) return [];

    final completer = Completer<List<GeocodingResult>>();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _searchNow(query, lat: lat, lng: lng);
        if (!completer.isCompleted) completer.complete(results);
      } catch (e) {
        if (!completer.isCompleted) completer.complete([]);
      }
    });

    return completer.future;
  }

  /// Immediate search without debounce
  Future<List<GeocodingResult>> _searchNow(String query,
      {double? lat, double? lng}) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '8',
        'countrycodes': 'vn',
      };

      // Bias towards user's location if available
      if (lat != null && lng != null) {
        params['viewbox'] =
            '${lng - 0.5},${lat + 0.5},${lng + 0.5},${lat - 0.5}';
        params['bounded'] = '0';
      }

      final response = await _dio.get('/search', queryParameters: params);

      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((item) {
          final name = item['name'] ?? item['display_name'].split(',').first;
          return GeocodingResult(
            name: name,
            displayName: item['display_name'] ?? '',
            lat: double.parse(item['lat']),
            lng: double.parse(item['lon']),
            type: item['type'] ?? 'place',
          );
        }).toList();
      }
    } catch (e) {
      // Silently fail — show empty results
    }
    return [];
  }

  /// Reverse geocode coordinates to address
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
        'addressdetails': '1',
      });

      if (response.statusCode == 200) {
        return response.data['display_name'];
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _dio.close();
  }
}
