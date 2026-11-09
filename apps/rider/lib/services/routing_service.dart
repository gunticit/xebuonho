import 'dart:math';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

class RouteData {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
  final String source;

  RouteData({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    required this.source,
  });
}

class RoutingService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  Future<RouteData> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // 1. Try API Gateway Route endpoint
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.route}',
        queryParameters: {
          'pickup_lat': startLat,
          'pickup_lng': startLng,
          'dropoff_lat': endLat,
          'dropoff_lng': endLng,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final rawPoints = res.data['points'] as List?;
        if (rawPoints != null && rawPoints.isNotEmpty) {
          final points = rawPoints.map<LatLng>((p) {
            return LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            );
          }).toList();

          return RouteData(
            points: points,
            distanceKm: (res.data['distance_km'] as num).toDouble(),
            durationMin: (res.data['duration_min'] as num).toInt(),
            source: res.data['source'] ?? 'gateway',
          );
        }
      }
    } catch (_) {}

    // 2. Direct OSRM Fallback
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data != null) {
        final routes = res.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r0 = routes[0];
          final coords = r0['geometry']['coordinates'] as List?;
          if (coords != null && coords.isNotEmpty) {
            final points = coords.map<LatLng>((c) {
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();

            final distKm =
                ((r0['distance'] as num).toDouble() / 1000.0 * 100).round() / 100;
            final durMin =
                max(3, ((r0['duration'] as num).toDouble() / 60.0).ceil());

            return RouteData(
              points: points,
              distanceKm: distKm,
              durationMin: durMin,
              source: 'osrm_direct',
            );
          }
        }
      }
    } catch (_) {}

    // 3. Realistic curved fallback
    return _generateCurvedFallback(startLat, startLng, endLat, endLng);
  }

  RouteData _generateCurvedFallback(
      double pLat, double pLng, double dLat, double dLng) {
    const earthR = 6371.0;
    final dLatRad = (dLat - pLat) * pi / 180.0;
    final dLngRad = (dLng - pLng) * pi / 180.0;
    final rLat1 = pLat * pi / 180.0;
    final rLat2 = dLat * pi / 180.0;

    final a = sin(dLatRad / 2) * sin(dLatRad / 2) +
        sin(dLngRad / 2) * sin(dLngRad / 2) * cos(rLat1) * cos(rLat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final straightKm = max(0.5, earthR * c);
    final roadKm = ((straightKm * 1.35) * 100).round() / 100;
    final durMin = max(3, ((roadKm / 28.0) * 60).ceil() + 3);

    const steps = 30;
    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final curve = sin(t * pi * 2) * 0.0025;
      points.add(LatLng(
        pLat + (dLat - pLat) * t + curve,
        pLng + (dLng - pLng) * t - curve,
      ));
    }

    return RouteData(
      points: points,
      distanceKm: roadKm,
      durationMin: durMin,
      source: 'curved_fallback',
    );
  }

  /// Calculate bearing angle in degrees between two coordinates (0 = North, 90 = East, 180 = South, 270 = West)
  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLng = (end.longitude - start.longitude) * pi / 180;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    final deg = (atan2(y, x) * 180 / pi + 360) % 360;
    return deg;
  }
}

