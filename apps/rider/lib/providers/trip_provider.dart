import 'package:flutter/foundation.dart';

import '../models/trip.dart';
import '../services/api_service.dart';

enum TripLoadState { idle, loading, loaded, error }

/// Quản lý lịch sử chuyến (đọc từ trip-service qua gateway).
class TripProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  final List<TripModel> _trips = [];
  TripLoadState _state = TripLoadState.idle;
  String? _errorMessage;

  List<TripModel> get trips => List.unmodifiable(_trips);
  TripLoadState get state => _state;
  String? get errorMessage => _errorMessage;

  bool get hasData => _trips.isNotEmpty;

  List<TripModel> tripsByService(Set<String> types) =>
      _trips.where((t) => types.contains(t.serviceType)).toList();

  Future<void> loadTrips({bool refresh = false}) async {
    if (_state == TripLoadState.loading) return;
    if (refresh) _trips.clear();
    _state = TripLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.getTripHistory();
      final parsed = data.map(TripModel.fromJson).toList();
      _trips
        ..clear()
        ..addAll(parsed);
      _state = TripLoadState.loaded;
    } catch (e) {
      _state = TripLoadState.error;
      _errorMessage = 'Không tải được lịch sử chuyến. Kiểm tra kết nối và thử lại.';
      debugPrint('[TripProvider] loadTrips error: $e');
    }
    notifyListeners();
  }

  Future<void> refresh() => loadTrips(refresh: true);
}
