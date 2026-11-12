import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

/// WebSocket client nối vào gateway /ws — nhận push realtime:
/// - ride_accepted: tài xế đã nhận cuốc của mình
/// - ride_status_updated: accepted/arrived/in_progress/completed/cancelled
/// Polling 3s ở tracking screen vẫn chạy làm fallback khi WS rớt.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String? _token;
  bool _reconnecting = false;
  int _reconnectDelay = 3; // giây, tăng dần khi fail liên tiếp

  final _rideEventsController = StreamController<Map<String, dynamic>>.broadcast();

  /// Sự kiện realtime cho booking flow: {type, order_id, status, driver_name...}
  Stream<Map<String, dynamic>> get rideEvents => _rideEventsController.stream;
  bool get isConnected => _channel != null;

  void connect(String token) {
    if (_token == token && _channel != null) return;
    _token = token;
    _reconnectDelay = 3;
    _disconnectSocket();
    _openSocket();
  }

  void _openSocket() {
    final token = _token;
    if (token == null) return;
    try {
      final uri = Uri.parse(ApiConfig.wsUrl).replace(queryParameters: {'token': token});
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _sub = channel.stream.listen(
        (msg) {
          _handleMessage(msg.toString());
          _reconnectDelay = 3; // kết nối tốt → reset backoff
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[ws] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(String raw) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (data['type'] != 'notification') return;
    final n = data['notification'];
    if (n is! Map) return;
    final type = n['type']?.toString();
    if (type != 'ride_accepted' && type != 'ride_status_updated') return;

    final payload = <String, dynamic>{'type': type};
    final d = n['data'];
    if (d is Map) {
      payload.addAll(Map<String, dynamic>.from(d));
    }
    _rideEventsController.add(payload);
    debugPrint('[ws] ride event: $payload');
  }

  void _scheduleReconnect() {
    _disconnectSocket();
    if (_token == null || _reconnecting) return;
    _reconnecting = true;
    Future.delayed(Duration(seconds: _reconnectDelay), () {
      _reconnecting = false;
      if (_token != null) {
        _reconnectDelay = (_reconnectDelay * 2).clamp(3, 60);
        _openSocket();
      }
    });
  }

  void disconnect() {
    _token = null;
    _disconnectSocket();
  }

  void _disconnectSocket() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
