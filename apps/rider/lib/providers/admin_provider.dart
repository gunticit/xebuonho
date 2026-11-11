import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum AdminLoadState { idle, loading, loaded, error }

class AdminProvider extends ChangeNotifier {
  AdminLoadState _state = AdminLoadState.idle;
  List<Map<String, dynamic>> _drivers = [];
  String? _error;

  // Filters
  String _statusFilter = 'pending_approval';
  String _kindFilter = '';

  AdminLoadState get state => _state;
  List<Map<String, dynamic>> get drivers => _drivers;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  String get kindFilter => _kindFilter;

  void setFilters({String? status, String? kind}) {
    if (status != null) _statusFilter = status;
    if (kind != null) _kindFilter = kind;
    notifyListeners();
  }

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
}
