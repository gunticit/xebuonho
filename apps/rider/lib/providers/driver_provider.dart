import 'dart:async';
import 'package:flutter/material.dart';
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
  DriverTrip? _currentTrip;
  final List<DriverTrip> _completedTrips = [];

  // Getters
  DriverStatus get status => _status;
  bool get isOnline => _status == DriverStatus.online;
  bool get isBusy => _status == DriverStatus.busy;
  DriverDailyStats get stats => _stats;
  DriverRideRequest? get incomingRequest => _incomingRequest;
  int get incomingCountdown => _incomingCountdown;
  DriverTrip? get currentTrip => _currentTrip;
  List<DriverTrip> get completedTrips => List.unmodifiable(_completedTrips);

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ==========================================
  // Online / Offline Management
  // ==========================================
  void toggleOnline(bool online) {
    if (online) {
      _status = DriverStatus.online;
      _startPolling();
    } else {
      _status = DriverStatus.offline;
      _clearIncoming();
      _pollingTimer?.cancel();
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

  Future<void> _pollPendingOrders() async {
    if (_status != DriverStatus.online || _incomingRequest != null || _currentTrip != null) {
      return;
    }

    try {
      final requests = await ApiService().getDriverRequests();
      if (requests.isNotEmpty && _status == DriverStatus.online && _incomingRequest == null && _currentTrip == null) {
        final raw = requests.first;
        final req = DriverRideRequest(
          id: raw['id']?.toString() ?? 'REQ-${DateTime.now().millisecondsSinceEpoch % 10000}',
          riderName: raw['customer_name']?.toString() ?? 'Trần Minh Quang',
          riderPhone: raw['customer_phone']?.toString() ?? '0988 123 456',
          riderRating: (raw['customer_rating'] as num?)?.toDouble() ?? 4.9,
          pickupAddress: raw['pickup_address']?.toString() ?? '72 Lê Thánh Tôn, Bến Nghé, Quận 1',
          pickupLat: (raw['pickup_lat'] as num?)?.toDouble() ?? 10.7769,
          pickupLng: (raw['pickup_lng'] as num?)?.toDouble() ?? 106.7009,
          dropoffAddress: raw['dropoff_address']?.toString() ?? 'Landmark 81, Vinhomes Central Park',
          dropoffLat: (raw['dropoff_lat'] as num?)?.toDouble() ?? 10.7950,
          dropoffLng: (raw['dropoff_lng'] as num?)?.toDouble() ?? 106.7218,
          distanceKm: (raw['distance_km'] as num?)?.toDouble() ?? 4.8,
          durationMin: (raw['duration_min'] as num?)?.toInt() ?? 14,
          fare: (raw['fare_estimate'] as num?)?.toDouble() ?? 68000,
          paymentMethod: raw['payment_method']?.toString() ?? 'Tiền mặt',
          serviceType: ServiceType.ride,
          vehicleType: VehicleType.car,
          notes: raw['notes']?.toString(),
        );

        simulateIncomingRide(customRequest: req);
      }
    } catch (_) {
      // Fallback safely
    }
  }

  // ==========================================
  // Incoming Ride Simulation & Handling
  // ==========================================
  void simulateIncomingRide({DriverRideRequest? customRequest}) {
    if (_status != DriverStatus.online || _currentTrip != null) return;

    _incomingRequest = customRequest ??
        DriverRideRequest(
          id: 'REQ-${DateTime.now().millisecondsSinceEpoch % 10000}',
          riderName: 'Trần Minh Quang',
          riderPhone: '0988 123 456',
          riderRating: 4.95,
          pickupAddress: '72 Lê Thánh Tôn, Bến Nghé, Quận 1, TP.HCM',
          pickupLat: 10.7769,
          pickupLng: 106.7009,
          dropoffAddress: 'Landmark 81, Vinhomes Central Park, Bình Thạnh',
          dropoffLat: 10.7950,
          dropoffLng: 106.7218,
          distanceKm: 4.8,
          durationMin: 14,
          fare: 68000,
          driverEarning: 54400,
          serviceType: ServiceType.ride,
          vehicleType: VehicleType.car,
          paymentMethod: 'Tiền mặt',
          notes: 'Khách đứng ngay sảnh Vincom Đồng Khởi',
        );

    _incomingCountdown = 15;
    _startCountdown();
    notifyListeners();
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
        // reschedule next
        _scheduleMockRide();
      }
    });
  }

  void _scheduleMockRide() {
    _startPolling();
  }

  void _clearIncoming() {
    _countdownTimer?.cancel();
    _incomingRequest = null;
    _incomingCountdown = 15;
    notifyListeners();
  }

  // Accept Ride
  void acceptIncomingRide() {
    if (_incomingRequest == null) return;
    _countdownTimer?.cancel();

    final req = _incomingRequest!;
    _currentTrip = DriverTrip(
      id: 'TRIP-${DateTime.now().millisecondsSinceEpoch % 10000}',
      request: req,
      status: DriverTripStatus.arrivingPickup,
    );
    _incomingRequest = null;
    _status = DriverStatus.busy;
    notifyListeners();

    // Notify backend / PostgreSQL asynchronously
    ApiService().acceptDriverRequest(req.id);
  }

  // Reject Ride
  void rejectIncomingRide() {
    _clearIncoming();
    _scheduleMockRide();
  }

  // ==========================================
  // Trip Progress Handling
  // ==========================================
  void advanceTripStatus() {
    if (_currentTrip == null) return;

    switch (_currentTrip!.status) {
      case DriverTripStatus.accepted:
        _currentTrip!.status = DriverTripStatus.arrivingPickup;
        break;
      case DriverTripStatus.arrivingPickup:
        _currentTrip!.status = DriverTripStatus.arrivedPickup;
        ApiService().updateDriverTripStatus(_currentTrip!.request.id, 'arrived');
        break;
      case DriverTripStatus.arrivedPickup:
        _currentTrip!.status = DriverTripStatus.inProgress;
        ApiService().updateDriverTripStatus(_currentTrip!.request.id, 'picked_up');
        break;
      case DriverTripStatus.inProgress:
        completeCurrentTrip();
        return;
      case DriverTripStatus.completed:
      case DriverTripStatus.cancelled:
        break;
    }
    notifyListeners();
  }

  void completeCurrentTrip() {
    if (_currentTrip == null) return;

    final trip = _currentTrip!;
    trip.status = DriverTripStatus.completed;
    trip.completedAt = DateTime.now();
    _completedTrips.insert(0, trip);

    // Update stats
    _stats = _stats.copyWith(
      todayEarnings: _stats.todayEarnings + trip.request.driverEarning,
      tripsCompleted: _stats.tripsCompleted + 1,
    );

    // Notify backend / PostgreSQL
    ApiService().updateDriverTripStatus(trip.request.id, 'completed');

    _currentTrip = null;
    _status = DriverStatus.online;
    notifyListeners();

    // Resume polling
    _scheduleMockRide();
  }

  void cancelCurrentTrip() {
    if (_currentTrip == null) return;
    final trip = _currentTrip!;
    trip.status = DriverTripStatus.cancelled;
    _completedTrips.insert(0, trip);

    // Notify backend / PostgreSQL
    ApiService().updateDriverTripStatus(trip.request.id, 'cancelled');

    _currentTrip = null;
    _status = DriverStatus.online;
    notifyListeners();
    _scheduleMockRide();
  }
}
