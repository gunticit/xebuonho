import 'dart:async';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

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

  /// Immediate search with Amazon Location Service (fallback to Nominatim OSM)
  Future<List<GeocodingResult>> _searchNow(String query,
      {double? lat, double? lng}) async {
    // 1. Try Amazon Location Service Places API if API key is present
    if (ApiConfig.awsLocationApiKey.isNotEmpty) {
      try {
        final awsResults = await _searchWithAmazonLocation(query, lat: lat, lng: lng);
        if (awsResults.isNotEmpty) {
          return awsResults;
        }
      } catch (_) {
        // Fallback to OSM Nominatim
      }
    }

    // 2. Fallback to Nominatim OSM
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

  /// Search places using Amazon Location Service Places API
  Future<List<GeocodingResult>> _searchWithAmazonLocation(String query,
      {double? lat, double? lng}) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ));

    final url = '${ApiConfig.awsLocationPlacesSearchUrl}?key=${ApiConfig.awsLocationApiKey}';
    final payload = <String, dynamic>{
      'Text': query,
      'MaxResults': 8,
      'FilterCountries': ['VNM'],
    };

    if (lat != null && lng != null) {
      payload['BiasPosition'] = [lng, lat];
    }

    final res = await dio.post(
      url,
      data: payload,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (res.statusCode == 200 && res.data != null) {
      final results = res.data['Results'] as List?;
      if (results != null && results.isNotEmpty) {
        return results.map((item) {
          final place = item['Place'] as Map<String, dynamic>? ?? {};
          final label = place['Label'] as String? ?? query;
          final point = place['Geometry']?['Point'] as List?;
          final pointLng = point != null && point.isNotEmpty ? (point[0] as num).toDouble() : (lng ?? 106.7009);
          final pointLat = point != null && point.length > 1 ? (point[1] as num).toDouble() : (lat ?? 10.7769);
          final shortName = label.split(',').first.trim();

          return GeocodingResult(
            name: shortName,
            displayName: label,
            lat: pointLat,
            lng: pointLng,
            type: 'place',
          );
        }).toList();
      }
    }

    return [];
  }

  /// Reverse geocode coordinates to address
  Future<String?> reverseGeocode(double lat, double lng) async {
    // 1. Try Backend API Gateway Reverse Geocode (Handles CORS, caching & fallback)
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final res = await dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.reverseGeocode}',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      if (res.statusCode == 200 && res.data != null) {
        final addr = res.data['address'] as String?;
        if (addr != null && addr.isNotEmpty) {
          return addr;
        }
      }
    } catch (_) {}

    // 2. Try Amazon Location Service Reverse Geocoding
    if (ApiConfig.awsLocationApiKey.isNotEmpty) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ));
        final url = 'https://places.geo.${ApiConfig.awsLocationRegion}.amazonaws.com/places/v0/indexes/${ApiConfig.awsLocationPlaceIndex}/search/position?key=${ApiConfig.awsLocationApiKey}';
        final res = await dio.post(
          url,
          data: {
            'Position': [lng, lat],
            'MaxResults': 1,
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final results = res.data['Results'] as List?;
          if (results != null && results.isNotEmpty) {
            return results[0]['Place']?['Label'] as String?;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to Nominatim OSM
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

    // 4. Regional Heuristic Fallback
    if (lat >= 12.80 && lat <= 13.15 && lng >= 108.10 && lng <= 108.45) {
      return lat > 12.95 ? 'Huyện Krông Búk, Đắk Lắk' : 'Thị xã Buôn Hồ, Đắk Lắk';
    } else if (lat >= 12.50 && lat <= 12.80 && lng >= 107.90 && lng <= 108.20) {
      return 'TP. Buôn Ma Thuột, Đắk Lắk';
    } else if (lat >= 10.60 && lat <= 10.95 && lng >= 106.50 && lng <= 106.90) {
      return 'TP. Hồ Chí Minh';
    } else if (lat >= 20.90 && lat <= 21.20 && lng >= 105.65 && lng <= 106.00) {
      return 'TP. Hà Nội';
    }
    return 'Vị trí (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  void dispose() {
    _debounceTimer?.cancel();
    _dio.close();
  }
}
