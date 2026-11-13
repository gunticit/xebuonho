import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum AdminLoadState { idle, loading, loaded, error }

class AdminProvider extends ChangeNotifier {
  AdminLoadState _state = AdminLoadState.idle;
  List<Map<String, dynamic>> _drivers = [];
  String? _error;

  // Filters for KYC
  String _statusFilter = 'pending_approval';
  String _kindFilter = '';

  // Stats & Analytics
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _revenueChart = [];
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _fleetDrivers = [];
  bool _isLoadingStats = false;
  bool _isLoadingOrders = false;
  bool _isLoadingFleet = false;

  AdminLoadState get state => _state;
  List<Map<String, dynamic>> get drivers => _drivers;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  String get kindFilter => _kindFilter;

  Map<String, dynamic>? get stats => _stats;
  List<Map<String, dynamic>> get revenueChart => _revenueChart;
  List<Map<String, dynamic>> get recentOrders => _recentOrders;
  List<Map<String, dynamic>> get fleetDrivers => _fleetDrivers;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingFleet => _isLoadingFleet;

  void setFilters({String? status, String? kind}) {
    if (status != null) _statusFilter = status;
    if (kind != null) _kindFilter = kind;
    notifyListeners();
  }

  // ========== KYC Moderation ==========
  Future<void> loadDrivers() async {
    _state = AdminLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _drivers = await ApiService().adminListDrivers(
        status: _statusFilter,
        kind: _kindFilter,
      );
      _state = AdminLoadState.loaded;
    } catch (e) {
      _state = AdminLoadState.error;
      _error = 'Không tải được danh sách hồ sơ: $e';
    }
    notifyListeners();
  }

  /// Chi tiết hồ sơ cho màn hình moderation (user + doc_urls presigned + warnings)
  Future<Map<String, dynamic>> loadDriverDetail(String driverId) async {
    return await ApiService().adminDriverDetail(driverId);
  }

  /// Duyệt / từ chối / khoá hồ sơ. Trả null nếu thành công, ngược lại là message lỗi.
  Future<String?> setApproval(String driverId, String status, {String reason = ''}) async {
    try {
      final res = await ApiService().adminSetApproval(driverId, status, reason: reason);
      if (res.statusCode == 200) {
        // Refresh list to reflect new status
        await loadDrivers();
        return null;
      }
      return 'Cập nhật thất bại (HTTP ${res.statusCode})';
    } catch (e) {
      return 'Cập nhật thất bại: $e';
    }
  }

  // ========== Stats & Overview ==========
  Future<void> loadStats() async {
    _isLoadingStats = true;
    notifyListeners();
    try {
      _stats = await ApiService().adminGetStats();
    } catch (_) {
      _stats = null;
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> loadRevenueChart() async {
    try {
      final res = await ApiService().adminGetRevenue();
      if (res['chart_data'] is List) {
        _revenueChart = (res['chart_data'] as List).cast<Map<String, dynamic>>();
      }
      notifyListeners();
    } catch (_) {}
  }

  // ========== Live Orders ==========
  Future<void> loadRecentOrders() async {
    _isLoadingOrders = true;
    notifyListeners();
    try {
      _recentOrders = await ApiService().adminGetRecentOrders();
    } catch (_) {
      _recentOrders = [];
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  // ========== Fleet Drivers ==========
  Future<void> loadFleetDrivers() async {
    _isLoadingFleet = true;
    notifyListeners();
    try {
      _fleetDrivers = await ApiService().adminGetNearbyDrivers();
    } catch (_) {
      _fleetDrivers = [];
    } finally {
      _isLoadingFleet = false;
      notifyListeners();
    }
  }

  /// Tải toàn bộ dữ liệu trang tổng quan
  Future<void> refreshAll() async {
    await Future.wait([
      loadStats(),
      loadRevenueChart(),
      loadRecentOrders(),
      loadFleetDrivers(),
      loadDrivers(),
    ]);
  }
}
