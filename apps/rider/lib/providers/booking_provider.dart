import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../services/api_service.dart';

enum BookingState {
  idle,
  selectingDestination,
  selectingVehicle,
  estimating,
  confirming,
  searching,
  driverFound,
  tracking,
  completed,
  cancelled,
}

class BookingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  BookingState _state = BookingState.idle;
  String _pickupAddress = '';
  double _pickupLat = 10.7769;
  double _pickupLng = 106.7009;
  String _dropoffAddress = '';
  double _dropoffLat = 0;
  double _dropoffLng = 0;
  VehicleType _vehicleType = VehicleType.car;
  String _paymentMethod = 'cash';
  String? _notes;

  // Fare estimates per vehicle type
  Map<VehicleType, double> _fareEstimates = {};

  RideModel? _currentRide;
  String? _error;

  // Getters
  BookingState get state => _state;
  String get pickupAddress => _pickupAddress;
  double get pickupLat => _pickupLat;
  double get pickupLng => _pickupLng;
  String get dropoffAddress => _dropoffAddress;
  double get dropoffLat => _dropoffLat;
  double get dropoffLng => _dropoffLng;
  VehicleType get vehicleType => _vehicleType;
  String get paymentMethod => _paymentMethod;
  String? get notes => _notes;
  Map<VehicleType, double> get fareEstimates => _fareEstimates;
  RideModel? get currentRide => _currentRide;
  String? get error => _error;
  bool get hasDestination => _dropoffAddress.isNotEmpty;

  // Set pickup
  void setPickup({required String address, required double lat, required double lng}) {
    _pickupAddress = address;
    _pickupLat = lat;
    _pickupLng = lng;
    notifyListeners();
  }

  // Set dropoff
  void setDropoff({required String address, required double lat, required double lng}) {
    _dropoffAddress = address;
    _dropoffLat = lat;
    _dropoffLng = lng;
    _state = BookingState.selectingVehicle;
    notifyListeners();
    estimateFare();
  }

  // Select vehicle
  void selectVehicle(VehicleType type) {
    _vehicleType = type;
    notifyListeners();
  }

  // Set payment
  void setPayment(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  // Set notes
  void setNotes(String? n) {
    _notes = n;
    notifyListeners();
  }

  // Estimate fare
  Future<void> estimateFare() async {
    _state = BookingState.estimating;
    _error = null;
    notifyListeners();

    try {
      // Calculate estimates for all vehicle types
      for (final vType in VehicleType.values) {
        final data = await _api.estimateFare(
          pickupLat: _pickupLat,
          pickupLng: _pickupLng,
          dropoffLat: _dropoffLat,
          dropoffLng: _dropoffLng,
          vehicleType: vType.name,
        );
        _fareEstimates[vType] = (data['fare_estimate'] as num?)?.toDouble() ?? 0;
      }
      _state = BookingState.confirming;
    } catch (e) {
      // Mock estimates if API unavailable
      _fareEstimates = {
        VehicleType.bike: 25000 + (_distanceEstimate() * 5000),
        VehicleType.car: 35000 + (_distanceEstimate() * 10000),
        VehicleType.premium: 50000 + (_distanceEstimate() * 15000),
      };
      _state = BookingState.confirming;
    }

    notifyListeners();
  }

  double _distanceEstimate() {
    // Simple Haversine approximation
    final dlat = (_dropoffLat - _pickupLat).abs();
    final dlng = (_dropoffLng - _pickupLng).abs();
    return (dlat + dlng) * 111; // rough km
  }

  // Book ride
  Future<void> bookRide() async {
    _state = BookingState.searching;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.createRide(
        pickupAddress: _pickupAddress,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        dropoffAddress: _dropoffAddress,
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        vehicleType: _vehicleType.name,
        paymentMethod: _paymentMethod,
        notes: _notes,
      );
      _currentRide = RideModel.fromJson(data);
      _state = BookingState.driverFound;
    } catch (e) {
      // Demo: simulate ride creation
      _currentRide = RideModel(
        id: 'RIDE-${DateTime.now().millisecondsSinceEpoch}',
        serviceType: ServiceType.ride,
        status: RideStatus.driverAssigned,
        pickupAddress: _pickupAddress,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        dropoffAddress: _dropoffAddress,
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        distanceKm: _distanceEstimate(),
        durationMin: (_distanceEstimate() * 3).toInt(),
        fareEstimate: _fareEstimates[_vehicleType] ?? 50000,
        paymentMethod: _paymentMethod,
        vehicleType: _vehicleType,
        createdAt: DateTime.now(),
      );
      _state = BookingState.driverFound;
    }

    notifyListeners();

    // Simulate driver found after 3s
    await Future.delayed(const Duration(seconds: 3));
    _state = BookingState.tracking;
    notifyListeners();
  }

  // Complete / Cancel
  void completeRide() {
    _state = BookingState.completed;
    notifyListeners();
  }

  void cancelRide() {
    _state = BookingState.cancelled;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), reset);
  }

  void reset() {
    _state = BookingState.idle;
    _dropoffAddress = '';
    _dropoffLat = 0;
    _dropoffLng = 0;
    _fareEstimates = {};
    _currentRide = null;
    _error = null;
    _notes = null;
    notifyListeners();
  }
}
