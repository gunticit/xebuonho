import 'package:dio/dio.dart';
import 'dart:math';

/// SePay Payment Gateway Service
/// Docs: https://docs.sepay.vn
/// Supports: VietQR bank transfer, Payment Gateway, Webhook
class SepayService {
  static const String baseUrl = 'https://my.sepay.vn/userapi';
  static const String qrBaseUrl = 'https://qr.sepay.vn/img';

  // Sandbox credentials (move to .env in production)
  static const String apiKey = 'EINV-TEST-R66C6SCYSZKRR30K';

  final Dio _dio;

  SepayService() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Generate VietQR URL for bank transfer
  /// SePay format: https://qr.sepay.vn/img?bank={bank}&acc={account}&template=compact&amount={amount}&des={description}
  static String generateQrUrl({
    required String bankName,
    required String accountNumber,
    required int amount,
    required String description,
    String template = 'compact',
  }) {
    final params = {
      'bank': bankName,
      'acc': accountNumber,
      'template': template,
      'amount': amount.toString(),
      'des': description,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$qrBaseUrl?$query';
  }

  /// Create an order reference for tracking
  static String generateOrderId() {
    final now = DateTime.now();
    final rng = Random();
    final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = rng.nextInt(9999).toString().padLeft(4, '0');
    return 'XBN$ts$rand';
  }

  /// Get transactions list (for verification)
  Future<Map<String, dynamic>?> getTransactions({
    String? accountNumber,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get('/transactions/list', queryParameters: {
        if (accountNumber != null) 'account_number': accountNumber,
        'limit': limit,
      });
      return response.data;
    } catch (e) {
      return null;
    }
  }

  /// Check if a specific payment has been received
  Future<bool> checkPayment({
    required String orderId,
    required int expectedAmount,
  }) async {
    try {
      final response = await _dio.get('/transactions/list', queryParameters: {
        'limit': 10,
      });

      if (response.data != null && response.data['transactions'] is List) {
        final transactions = response.data['transactions'] as List;
        return transactions.any((t) =>
          t['transaction_content']?.toString().contains(orderId) == true &&
          (t['amount_in'] as num?) == expectedAmount
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Bank account info for QR generation
class BankAccount {
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String logo;

  const BankAccount({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.logo = '',
  });
}

/// Pre-configured bank accounts for the app
class AppBankAccounts {
  static const primary = BankAccount(
    bankCode: 'MBBank',
    bankName: 'MB Bank',
    accountNumber: '0123456789',
    accountName: 'CONG TY XEBUONHO',
  );

  static const List<BankAccount> all = [primary];
}
