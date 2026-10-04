import 'dart:async';
import 'package:flutter/material.dart';
import '../models/driver_models.dart';
import '../models/ride.dart';

class DriverProvider extends ChangeNotifier {
  DriverStatus _status = DriverStatus.offline;
  DriverDailyStats _stats = const DriverDailyStats();
  DriverRideRequest? _incomingRequest;
  int _incomingCountdown = 15;
  Timer? _countdownTimer;
  Timer? _mockRequestTimer;
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
    _mockRequestTimer?.cancel();
    super.dispose();
  }

  // ==========================================
  // Online / Offline Management
  // ==========================================
  void toggleOnline(bool online) {
    if (online) {
      _status = DriverStatus.online;
      _scheduleMockRide();
    } else {
      _status = DriverStatus.offline;
      _clearIncoming();
      _mockRequestTimer?.cancel();
    }
    notifyListeners();
  }

  void _scheduleMockRide() {
    _mockRequestTimer?.cancel();
    // Schedule an incoming ride after 5 seconds of being online if idle
    _mockRequestTimer = Timer(const Duration(seconds: 5), () {
      if (_status == DriverStatus.online && _incomingRequest == null && _currentTrip == null) {
        simulateIncomingRide();
      }
    });
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

    _currentTrip = DriverTrip(
      id: 'TRIP-${DateTime.now().millisecondsSinceEpoch % 10000}',
      request: _incomingRequest!,
      status: DriverTripStatus.arrivingPickup,
    );
    _incomingRequest = null;
    _status = DriverStatus.busy;
    notifyListeners();
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
        break;
      case DriverTripStatus.arrivedPickup:
        _currentTrip!.status = DriverTripStatus.inProgress;
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

    _currentTrip!.status = DriverTripStatus.completed;
    _currentTrip!.completedAt = DateTime.now();
    _completedTrips.insert(0, _currentTrip!);

    // Update stats
    _stats = _stats.copyWith(
      todayEarnings: _stats.todayEarnings + _currentTrip!.request.driverEarning,
      tripsCompleted: _stats.tripsCompleted + 1,
    );

    _currentTrip = null;
    _status = DriverStatus.online;
    notifyListeners();

    // Schedule next ride
    _scheduleMockRide();
  }

  void cancelCurrentTrip() {
    if (_currentTrip == null) return;
    _currentTrip!.status = DriverTripStatus.cancelled;
    _completedTrips.insert(0, _currentTrip!);
    _currentTrip = null;
    _status = DriverStatus.online;
    notifyListeners();
    _scheduleMockRide();
  }
}
