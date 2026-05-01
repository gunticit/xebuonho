import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xebuonho_rider/main.dart';
import 'package:xebuonho_rider/models/app_models.dart';
import 'package:xebuonho_rider/services/sepay_service.dart';

void main() {
  testWidgets('App boots and navigates past splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'consent_accepted': true});
    await tester.pumpWidget(const XebuonhoApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    // Advance past splash 2s timer + animations
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  });

  group('CartItem totals', () {
    test('total = price * quantity', () {
      final item = MenuItem(id: '1', name: 'Phở', description: '', price: 50000);
      final cart = CartItem(item: item, quantity: 3);
      expect(cart.total, 150000);
    });

    test('default quantity is 1', () {
      final item = MenuItem(id: '1', name: 'Trà đá', description: '', price: 5000);
      expect(CartItem(item: item).quantity, 1);
      expect(CartItem(item: item).total, 5000);
    });
  });

  group('FoodOrder total', () {
    test('subtotal + delivery - discount', () {
      final order = FoodOrder(
        id: 'X1', restaurantName: 'Test', items: [],
        createdAt: DateTime.now(),
        deliveryAddress: '', paymentMethod: 'cash',
        subtotal: 100000, deliveryFee: 15000, discount: 20000,
      );
      expect(order.total, 95000);
    });
  });

  group('OrderStatus', () {
    test('all statuses have label and emoji', () {
      for (final s in OrderStatus.values) {
        expect(s.label.isNotEmpty, true);
        expect(s.emoji.isNotEmpty, true);
      }
    });
  });

  group('SepayService', () {
    test('generateOrderId starts with XBN and has correct length', () {
      final id = SepayService.generateOrderId();
      expect(id.startsWith('XBN'), true);
      expect(id.length, 'XBN'.length + 8 + 4);
    });

    test('generateQrUrl includes amount and description', () {
      final url = SepayService.generateQrUrl(
        bankName: 'MBBank',
        accountNumber: '0123456789',
        amount: 183000,
        description: 'XBN20260301001',
      );
      expect(url.contains('bank=MBBank'), true);
      expect(url.contains('acc=0123456789'), true);
      expect(url.contains('amount=183000'), true);
      expect(url.contains('des=XBN20260301001'), true);
    });
  });

  group('AddressType', () {
    test('home has correct emoji and name', () {
      expect(AddressType.home.emoji, '🏠');
      expect(AddressType.home.displayName, 'Nhà');
    });
  });
}
