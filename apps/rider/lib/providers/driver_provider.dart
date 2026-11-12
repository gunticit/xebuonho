import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_models.dart';
import '../models/ride.dart';
import '../services/api_service.dart';

class DriverProvider extends ChangeNotifier {
  DriverStatus _status = DriverStatus.offline;
  DriverDailyStats _stats = const DriverDailyStats();
  DriverRideRequest? _incomingRequest;
  int _incomingCountdown = 15;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  Timer? _locationTimer;
  DriverTrip? _currentTrip;
  final List<DriverTrip> _completedTrips = [];

  // Server history (GET /driver/history) cho màn lịch sử tài xế
  List<Map<String, dynamic>> _serverHistory = [];
  String? _lastError;

  // Getters
  DriverStatus get status => _status;
  bool get isOnline => _status == DriverStatus.online;
  bool get isBusy => _status == DriverStatus.busy;
  DriverDailyStats get stats => _stats;
  DriverRideRequest? get incomingRequest => _incomingRequest;
  int get incomingCountdown => _incomingCountdown;
  DriverTrip? get currentTrip => _currentTrip;
  List<DriverTrip> get completedTrips => List.unmodifiable(_completedTrips);
  List<Map<String, dynamic>> get serverHistory => List.unmodifiable(_serverHistory);
  String? get lastError => _lastError;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  // ==========================================
  // Online / Offline Management
  // ==========================================
  void toggleOnline(bool online) {
    if (online) {
      _status = DriverStatus.online;
      _startPolling();
      _startLocationReporting();
      // Sync cuốc đang dở từ server (trường hợp app reload giữa chuyến)
      _syncCurrentTripFromServer();
      _refreshEarningsFromServer();
      _loadServerHistory();
    } else {
      _status = DriverStatus.offline;
      _clearIncoming();
      _pollingTimer?.cancel();
      _locationTimer?.cancel();
    }
    notifyListeners();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Check immediately, then poll every 4 seconds
    _pollPendingOrders();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollPendingOrders();
    });
  }

  /// Gửi GPS lên gateway mỗi 10s khi online — rider tracking + nearby list
  /// đọc vị trí thật từ đây (per-driver store).
  void _startLocationReporting() {
    _locationTimer?.cancel();
    _reportLocationOnce();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _reportLocationOnce());
  }

  Future<void> _reportLocationOnce() async {
    if (_status == DriverStatus.offline) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiService().updateDriverLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        speed: pos.speed < 0 ? 0 : (pos.speed * 3.6), // m/s → km/h
        heading: pos.heading < 0 ? 0 : pos.heading,
      );
    } catch (_) {
      // GPS không khả dụng (web permission...) — bỏ qua chu kỳ này
    }
  }

  /// Khôi phục cuốc đang thực hiện từ server (nếu có).
  Future<void> _syncCurrentTripFromServer() async {
    if (_currentTrip != null) return;
    final trip = await ApiService().getCurrentDriverTrip();
    if (trip == null || !isOnline) return;
    final req = _requestFromMap(trip);
    if (req == null) return;
    final statusStr = trip['status']?.toString();
    _currentTrip = DriverTrip(
      id: req.id,
      request: req,
      status: statusStr == 'in_progress'
          ? DriverTripStatus.inProgress
          : (statusStr == 'arrived' ? DriverTripStatus.arrivedPickup : DriverTripStatus.arrivingPickup),
    );
    _status = DriverStatus.busy;
    notifyListeners();
  }

  Future<void> _refreshEarningsFromServer() async {
    final summary = await ApiService().getDriverEarnings();
    if (summary == null) return;
    _stats = _stats.copyWith(
      todayEarnings: (summary['today_earnings'] as num?)?.toDouble() ?? _stats.todayEarnings,
      tripsCompleted: (summary['today_trips'] as num?)?.toInt() ?? _stats.tripsCompleted,
    );
    notifyListeners();
  }

  Future<void> _loadServerHistory() async {
    _serverHistory = await ApiService().getDriverHistory();
    notifyListeners();
  }

  /// Public hook cho màn lịch sử (pull-to-refresh).
  Future<void> refreshServerHistory() => _loadServerHistory();

  // ==========================================
  // Incoming Ride Polling (đơn thật từ orders table)
  // ==========================================
  Future<void> _pollPendingOrders() async {
    if (_status != DriverStatus.online || _incomingRequest != null || _currentTrip != null) {
      return;
    }

    try {
      final requests = await ApiService().getDriverRequests();
      if (requests.isNotEmpty && _status == DriverStatus.online && _incomingRequest == null && _currentTrip == null) {
        final req = _requestFromMap(requests.first);
        if (req != null) {
          _incomingRequest = req;
          _incomingCountdown = 15;
          _startCountdown();
          notifyListeners();
        }
      }
    } catch (_) {
      // Fallback safely
    }
  }

  DriverRideRequest? _requestFromMap(Map<String, dynamic> raw) {
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return DriverRideRequest(
      id: id,
      riderName: raw['customer_name']?.toString() ?? 'Khách hàng',
      riderPhone: raw['customer_phone']?.toString() ?? '—',
      riderRating: (raw['customer_rating'] as num?)?.toDouble() ?? 4.9,
      pickupAddress: raw['pickup_address']?.toString() ?? '—',
      pickupLat: (raw['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (raw['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: raw['dropoff_address']?.toString() ?? '—',
      dropoffLat: (raw['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (raw['dropoff_lng'] as num?)?.toDouble() ?? 0,
      distanceKm: (raw['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (raw['duration_minutes'] as num?)?.toInt() ?? 0,
      fare: (raw['fare_estimate'] as num?)?.toDouble() ?? 0,
      paymentMethod: raw['payment_method']?.toString() ?? 'Tiền mặt',
      serviceType: ServiceType.fromString(raw['service_type']?.toString()),
      vehicleType: raw['vehicle_type'] == 'bike' ? VehicleType.bike : VehicleType.car,
      notes: raw['notes']?.toString(),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_incomingCountdown > 1) {
        _incomingCountdown--;
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
        _clearIncoming();
      }
    });
  }

  void _clearIncoming() {
    _countdownTimer?.cancel();
    _incomingRequest = null;
    _incomingCountdown = 15;
    notifyListeners();
  }

  // Accept Ride — gọi server TRƯỚC, thành công mới chuyển UI (ngược lại hiện lỗi)
  Future<void> acceptIncomingRide() async {
    if (_incomingRequest == null) return;
    _countdownTimer?.cancel();

    final req = _incomingRequest!;
    _lastError = await ApiService().acceptDriverRequest(req.id);
    if (_lastError != null) {
      // Nhận thất bại (403 chưa duyệt KYC / 409 đã có người nhận...) — trả lại hàng đợi
      _incomingRequest = null;
      _incomingCountdown = 15;
      notifyListeners();
      return;
    }

    _currentTrip = DriverTrip(
      id: req.id,
      request: req,
      status: DriverTripStatus.arrivingPickup,
    );
    _incomingRequest = null;
    _status = DriverStatus.busy;
    notifyListeners();
  }

  // Reject Ride
  void rejectIncomingRide() {
    _clearIncoming();
  }

  // ==========================================
  // Trip Progress Handling — mỗi bước gọi server trước
  // ==========================================
  Future<void> advanceTripStatus() async {
    if (_currentTrip == null) return;

    switch (_currentTrip!.status) {
      case DriverTripStatus.accepted:
        _currentTrip!.status = DriverTripStatus.arrivingPickup;
        break;
      case DriverTripStatus.arrivingPickup:
        final ok = await ApiService().updateDriverTripStatus(_currentTrip!.request.id, 'arrived');
        if (!ok) {
          _lastError = 'Không cập nhật được trạng thái lên server';
          notifyListeners();
          return;
        }
        _currentTrip!.status = DriverTripStatus.arrivedPickup;
        break;
      case DriverTripStatus.arrivedPickup:
        final ok = await ApiService().updateDriverTripStatus(_currentTrip!.request.id, 'picked_up');
        if (!ok) {
          _lastError = 'Không cập nhật được trạng thái lên server';
          notifyListeners();
          return;
        }
        _currentTrip!.status = DriverTripStatus.inProgress;
        break;
      case DriverTripStatus.inProgress:
        await completeCurrentTrip();
        return;
      case DriverTripStatus.completed:
      case DriverTripStatus.cancelled:
        break;
    }
    notifyListeners();
  }

  Future<void> completeCurrentTrip() async {
    if (_currentTrip == null) return;

    final trip = _currentTrip!;
    final ok = await ApiService().updateDriverTripStatus(trip.request.id, 'completed');
    if (!ok) {
      _lastError = 'Không hoàn tất được chuyến trên server';
      notifyListeners();
      return;
    }

    trip.status = DriverTripStatus.completed;
    trip.completedAt = DateTime.now();
    _completedTrips.insert(0, trip);

    _currentTrip = null;
    _status = DriverStatus.online;
    notifyListeners();

    // Sync thu nhập thật từ server + làm mới lịch sử
    _refreshEarningsFromServer();
    _loadServerHistory();
    _startPolling();
  }

  Future<void> cancelCurrentTrip() async {
    if (_currentTrip == null) return;
    final trip = _currentTrip!;
    await ApiService().updateDriverTripStatus(trip.request.id, 'cancelled');
    trip.status = DriverTripStatus.cancelled;
    _completedTrips.insert(0, trip);

    _currentTrip = null;
    _status = DriverStatus.online;
    notifyListeners();
    _startPolling();
  }

  /// Đọc/xoá lỗi gần nhất (dashboard hiển thị snackbar).
  String? consumeError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }
}
