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
      case 'market':
      case 'marketplace':
        return '🛍️';
      case 'hotel':
        return '🏨';
      case 'park':
      case 'garden':
        return '🌳';
      case 'bus_station':
      case 'station':
        return '🚌';
      case 'junction':
        return '🚦';
      case 'government':
        return '🏛️';
      case 'town':
      case 'city':
        return '🏙️';
      case 'village':
        return '🏡';
      default:
        return '📍';
    }
  }
}

/// Pre-indexed catalog of all key locations in Buôn Hồ, Krông Búk & Đắk Lắk
final List<Map<String, dynamic>> _kLocalDakLakCatalog = [
  {
    'name': 'Pơng Drang',
    'displayName': 'Thị trấn Pơng Drang, Huyện Krông Búk, Đắk Lắk',
    'lat': 12.9628,
    'lng': 108.2465,
    'type': 'town',
    'keywords': 'pongdrang pong drang pơngdrang pơng drang krong buk thi tran pong drang',
  },
  {
    'name': 'Ngã ba Pơng Drang',
    'displayName': 'Quốc lộ 14, Thị trấn Pơng Drang, Krông Búk',
    'lat': 12.9640,
    'lng': 108.2470,
    'type': 'junction',
    'keywords': 'nga ba pong drang nga 3 pongdrang nga ba pơng drang ql14',
  },
  {
    'name': 'Chợ Pơng Drang',
    'displayName': 'Chợ Pơng Drang, QL14, Krông Búk, Đắk Lắk',
    'lat': 12.9615,
    'lng': 108.2482,
    'type': 'market',
    'keywords': 'cho pong drang cho pơngdrang cho krong buk',
  },
  {
    'name': 'UBND Huyện Krông Búk',
    'displayName': 'Trung tâm Hành chính Krông Búk, Đắk Lắk',
    'lat': 12.9700,
    'lng': 108.2400,
    'type': 'government',
    'keywords': 'ubnd krong buk huyen krong buk krongbuk',
  },
  {
    'name': 'Thị xã Buôn Hồ',
    'displayName': 'Trung tâm Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9247,
    'lng': 108.2541,
    'type': 'town',
    'keywords': 'buonho buôn hồ tx buon ho thi xa buon ho trung tam buon ho',
  },
  {
    'name': 'Chợ Buôn Hồ',
    'displayName': 'Đường Hùng Vương, Phường An Lạc, TX. Buôn Hồ',
    'lat': 12.9215,
    'lng': 108.2520,
    'type': 'market',
    'keywords': 'cho buon ho hung vuong an lac',
  },
  {
    'name': 'Bệnh viện Đa khoa Buôn Hồ',
    'displayName': 'Trần Hưng Đạo, Phường An Lạc, TX. Buôn Hồ',
    'lat': 12.9280,
    'lng': 108.2560,
    'type': 'hospital',
    'keywords': 'benh vien buon ho bv buon ho tran hung dao',
  },
  {
    'name': 'Bến xe Buôn Hồ',
    'displayName': 'Quốc lộ 14, Phường Thiện An, TX. Buôn Hồ',
    'lat': 12.9180,
    'lng': 108.2505,
    'type': 'bus_station',
    'keywords': 'ben xe buon ho bx buon ho ql14',
  },
  {
    'name': 'Quảng trường Buôn Hồ',
    'displayName': 'Quảng trường TX. Buôn Hồ, Đắk Lắk',
    'lat': 12.9230,
    'lng': 108.2535,
    'type': 'park',
    'keywords': 'quang truong buon ho',
  },
  {
    'name': 'Xã Ea Siên',
    'displayName': 'Xã Ea Siên, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.8500,
    'lng': 108.3100,
    'type': 'village',
    'keywords': 'easien ea sien xa ea sien buôn hồ',
  },
  {
    'name': 'Xã Ea Drông',
    'displayName': 'Xã Ea Drông, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9800,
    'lng': 108.3200,
    'type': 'village',
    'keywords': 'eadrong ea drong xa ea drong buôn hồ',
  },
  {
    'name': 'Xã Ea Blang',
    'displayName': 'Xã Ea Blang, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9400,
    'lng': 108.2800,
    'type': 'village',
    'keywords': 'eablang ea blang xa ea blang',
  },
  {
    'name': 'Phường An Lạc',
    'displayName': 'Phường An Lạc, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9200,
    'lng': 108.2500,
    'type': 'suburb',
    'keywords': 'an lac phuong an lac buon ho',
  },
  {
    'name': 'Phường Thiện An',
    'displayName': 'Phường Thiện An, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9100,
    'lng': 108.2650,
    'type': 'suburb',
    'keywords': 'thien an phuong thien an buon ho',
  },
  {
    'name': 'Phường Thống Nhất',
    'displayName': 'Phường Thống Nhất, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9450,
    'lng': 108.2480,
    'type': 'suburb',
    'keywords': 'thong nhat thongnhat phuong thong nhat',
  },
  {
    'name': 'Phường Đoàn Kết',
    'displayName': 'Phường Đoàn Kết, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9350,
    'lng': 108.2420,
    'type': 'suburb',
    'keywords': 'doan ket doanket phuong doan ket',
  },
  {
    'name': 'Phường Bình Tân',
    'displayName': 'Phường Bình Tân, Thị xã Buôn Hồ, Đắk Lắk',
    'lat': 12.9150,
    'lng': 108.2400,
    'type': 'suburb',
    'keywords': 'binh tan binhtan phuong binh tan',
  },
  {
    'name': 'Xã Chư Kabô',
    'displayName': 'Xã Chư Kabô, Huyện Krông Búk, Đắk Lắk',
    'lat': 12.9850,
    'lng': 108.2300,
    'type': 'village',
    'keywords': 'chukabo chu kabo krong buk',
  },
  {
    'name': 'Xã Cư Pơng',
    'displayName': 'Xã Cư Pơng, Huyện Krông Búk, Đắk Lắk',
    'lat': 13.0200,
    'lng': 108.2100,
    'type': 'village',
    'keywords': 'cupong cu pong cu poeng krong buk',
  },
  {
    'name': 'Xã Cư Né',
    'displayName': 'Xã Cư Né, Huyện Krông Búk, Đắk Lắk',
    'lat': 13.0100,
    'lng': 108.2600,
    'type': 'village',
    'keywords': 'cune cu ne krong buk',
  },
  {
    'name': 'Thị trấn Ea Drăng',
    'displayName': 'Thị trấn Ea Drăng, Huyện Ea H\'leo, Đắk Lắk',
    'lat': 13.2100,
    'lng': 108.1900,
    'type': 'town',
    'keywords': 'eadrang eahleo ea hleo ea drang',
  },
  {
    'name': 'Thị trấn Quảng Phú',
    'displayName': 'Thị trấn Quảng Phú, Huyện Cư M\'gar, Đắk Lắk',
    'lat': 12.8100,
    'lng': 108.1100,
    'type': 'town',
    'keywords': 'quang phu quangphu cumgar cu mgar',
  },
  {
    'name': 'Thị trấn Krông Năng',
    'displayName': 'Thị trấn Krông Năng, Huyện Krông Năng, Đắk Lắk',
    'lat': 12.9500,
    'lng': 108.4300,
    'type': 'town',
    'keywords': 'krong nang krongnang',
  },
  {
    'name': 'Thị trấn Phước An',
    'displayName': 'Thị trấn Phước An, Huyện Krông Pắc, Đắk Lắk',
    'lat': 12.7200,
    'lng': 108.3100,
    'type': 'town',
    'keywords': 'phuoc an phuocan krong pac',
  },
  {
    'name': 'Ngã 6 Buôn Ma Thuột',
    'displayName': 'Tượng đài Chiến thắng, TP. Buôn Ma Thuột',
    'lat': 12.6840,
    'lng': 108.0475,
    'type': 'landmark',
    'keywords': 'nga 6 bmt nga sau bmt buon ma thuot bmt',
  },
  {
    'name': 'Sân bay Buôn Ma Thuột (BMV)',
    'displayName': 'Cảng hàng không Buôn Ma Thuột, Hòa Thắng, BMT',
    'lat': 12.6680,
    'lng': 108.1200,
    'type': 'aeroway',
    'keywords': 'san bay bmt san bay buon ma thuot bmv',
  },
  {
    'name': 'Bến xe Liên tỉnh Đắk Lắk',
    'displayName': 'Km4 Nguyễn Tất Thành, TP. Buôn Ma Thuột',
    'lat': 12.7050,
    'lng': 108.0700,
    'type': 'bus_station',
    'keywords': 'ben xe phia bac bmt ben xe lien tinh dak lak',
  },
];

/// Remove Vietnamese diacritics and special characters for flexible fuzzy search (NFD & NFC)
String normalizeVietnameseText(String str) {
  var s = str.toLowerCase();
  s = s.replaceAll('đ', 'd').replaceAll('Đ', 'd');
  const Map<String, String> map = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
  };
  map.forEach((k, v) {
    s = s.replaceAll(k, v);
  });
  // Strip combining diacritical marks (U+0300 to U+036F) for NFD support (Mac/iOS/Android keyboard)
  s = s.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  // Strip non-alphanumeric chars (spaces, hyphens, punctuation)
  s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return s;
}

String _normalizeVietnamese(String str) => normalizeVietnameseText(str);

/// Geocoding and Place Search service with instant local matching & multi-tier fallback
class GeocodingService {
  final Dio _dio;
  Timer? _debounceTimer;

  GeocodingService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ));

  /// Instant local search: matches pre-indexed Buôn Hồ / Krông Búk / Đắk Lắk places (0ms)
  List<GeocodingResult> searchLocal(String query) {
    if (query.trim().length < 2) return [];
    final normQ = _normalizeVietnamese(query);

    final results = <GeocodingResult>[];
    for (final p in _kLocalDakLakCatalog) {
      final normName = _normalizeVietnamese(p['name'] as String);
      final normDisplay = _normalizeVietnamese(p['displayName'] as String);
      final normKey = _normalizeVietnamese(p['keywords'] as String);

      if (normName.contains(normQ) ||
          normDisplay.contains(normQ) ||
          normKey.contains(normQ)) {
        results.add(GeocodingResult(
          name: p['name'] as String,
          displayName: p['displayName'] as String,
          lat: p['lat'] as double,
          lng: p['lng'] as double,
          type: p['type'] as String,
        ));
      }
    }
    return results;
  }

  /// Search for addresses with debounce (200ms) and multi-tier resolution
  Future<List<GeocodingResult>> search(String query,
      {double? lat, double? lng}) async {
    final cleanQ = query.trim();
    if (cleanQ.length < 2) return [];

    final completer = Completer<List<GeocodingResult>>();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final results = await _searchNow(cleanQ, lat: lat, lng: lng);
        if (!completer.isCompleted) completer.complete(results);
      } catch (e) {
        if (!completer.isCompleted) completer.complete(searchLocal(cleanQ));
      }
    });

    return completer.future;
  }

  Future<List<GeocodingResult>> _searchNow(String query,
      {double? lat, double? lng}) async {
    final combined = <GeocodingResult>[];

    // 1. Instant local search match
    final localMatches = searchLocal(query);
    combined.addAll(localMatches);

    // 2. Try API Gateway Search endpoint
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.searchPlaces}',
        queryParameters: {'q': query, 'lat': lat, 'lng': lng},
      );
      if (res.statusCode == 200 && res.data is List) {
        for (final item in res.data) {
          final latVal = (item['lat'] as num).toDouble();
          final lngVal = (item['lng'] as num).toDouble();
          if (!_isDuplicate(combined, latVal, lngVal)) {
            combined.add(GeocodingResult(
              name: item['name'] ?? '',
              displayName: item['display_name'] ?? '',
              lat: latVal,
              lng: lngVal,
              type: item['type'] ?? 'place',
            ));
          }
        }
      }
    } catch (_) {}

    // 3. Fallback to Nominatim OSM with query variant expansion
    if (combined.length < 5) {
      final variants = _expandQueryVariants(query);
      for (final v in variants) {
        try {
          final params = <String, dynamic>{
            'q': v,
            'format': 'json',
            'addressdetails': '1',
            'limit': '6',
            'countrycodes': 'vn',
          };
          if (lat != null && lng != null) {
            params['viewbox'] =
                '${lng - 0.5},${lat + 0.5},${lng + 0.5},${lat - 0.5}';
            params['bounded'] = '0';
          }

          final response = await _dio.get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: params,
          );

          if (response.statusCode == 200 && response.data is List) {
            for (final item in response.data) {
              final latVal = double.tryParse(item['lat'].toString()) ?? 0;
              final lngVal = double.tryParse(item['lon'].toString()) ?? 0;
              if (latVal != 0 && !_isDuplicate(combined, latVal, lngVal)) {
                final name =
                    item['name'] ?? item['display_name'].split(',').first.trim();
                combined.add(GeocodingResult(
                  name: name,
                  displayName: item['display_name'] ?? '',
                  lat: latVal,
                  lng: lngVal,
                  type: item['type'] ?? 'place',
                ));
              }
            }
          }
        } catch (_) {}

        if (combined.length >= 6) break;
      }
    }

    return combined;
  }

  bool _isDuplicate(List<GeocodingResult> list, double lat, double lng) {
    for (final item in list) {
      if ((item.lat - lat).abs() < 0.003 && (item.lng - lng).abs() < 0.003) {
        return true;
      }
    }
    return false;
  }

  List<String> _expandQueryVariants(String q) {
    final variants = <String>[q];
    final norm = _normalizeVietnamese(q);

    if (norm == 'pongdrang') {
      variants.add('Pơng Drang');
      variants.add('Pong Drang');
    } else if (norm == 'eahleo') {
      variants.add('Ea H\'leo');
      variants.add('Ea Hleo');
    } else if (norm == 'krongbuk') {
      variants.add('Krông Búk');
      variants.add('Krong Buk');
    } else if (norm == 'buonho') {
      variants.add('Buôn Hồ');
      variants.add('Buon Ho');
    } else if (norm == 'bmt') {
      variants.add('Buôn Ma Thuột');
      variants.add('Buon Ma Thuot');
    } else if (norm == 'cumgar') {
      variants.add('Cư M\'gar');
      variants.add('Cu Mgar');
    } else if (norm == 'easien') {
      variants.add('Ea Siên');
    } else if (norm == 'eadrong') {
      variants.add('Ea Drông');
    }

    // Split concatenated words like "ngabapongdrang" -> "Ngã ba Pơng Drang"
    if (norm.startsWith('ngaba')) {
      variants.add('Ngã ba ${q.substring(5).trim()}');
    }
    if (norm.startsWith('cho')) {
      variants.add('Chợ ${q.substring(3).trim()}');
    }

    return variants;
  }

  /// Reverse geocode coordinates to address
  Future<String?> reverseGeocode(double lat, double lng) async {
    // 1. Try Backend API Gateway Reverse Geocode
    try {
      final res = await _dio.get(
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

    // 2. Try Nominatim OSM
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'addressdetails': '1',
        },
      );
      if (response.statusCode == 200) {
        return response.data['display_name'];
      }
    } catch (_) {}

    // 3. Regional Heuristic Fallback
    if (lat >= 12.80 && lat <= 13.15 && lng >= 108.10 && lng <= 108.45) {
      return lat > 12.95 ? 'Huyện Krông Búk, Đắk Lắk' : 'Thị xã Buôn Hồ, Đắk Lắk';
    } else if (lat >= 12.50 && lat <= 12.80 && lng >= 107.90 && lng <= 108.20) {
      return 'TP. Buôn Ma Thuột, Đắk Lắk';
    } else if (lat >= 10.60 && lat <= 10.95 && lng >= 106.50 && lng <= 106.90) {
      return 'TP. Hồ Chí Minh';
    }
    return 'Vị trí (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  void dispose() {
    _debounceTimer?.cancel();
    _dio.close();
  }
}
