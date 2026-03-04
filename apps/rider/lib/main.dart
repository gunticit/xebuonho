import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/location_provider.dart';

// Core screens
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';

// Ride flow
import 'screens/search_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/trip_complete_screen.dart';
import 'screens/ride_detail_screen.dart';

// Account & Menu
import 'screens/profile_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/promotions_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/support_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';
import 'screens/saved_addresses_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/top_up_screen.dart';
import 'screens/legal_screens.dart';

// Food delivery
import 'screens/food/restaurant_list_screen.dart';
import 'screens/food/restaurant_detail_screen.dart';
import 'screens/food/checkout_screen.dart';
import 'screens/food/order_tracking_screen.dart';
import 'screens/food/order_detail_screen.dart';
import 'screens/food/share_bill_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0B0F1A),
  ));

  runApp(const XebuonhoApp());
}

class XebuonhoApp extends StatelessWidget {
  const XebuonhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
      ],
      child: MaterialApp(
        title: 'Xebuonho',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          // Core
          '/': (_) => const SplashScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/login': (_) => const LoginScreen(),
          '/otp': (_) => const OtpScreen(),
          '/home': (_) => const HomeScreen(),

          // Ride flow
          '/search': (_) => const SearchScreen(),
          '/booking': (_) => const BookingScreen(),
          '/tracking': (_) => const TrackingScreen(),
          '/complete': (_) => const TripCompleteScreen(),
          '/ride-detail': (_) => const RideDetailScreen(),

          // Account & Menu
          '/profile': (_) => const ProfileScreen(),
          '/payment': (_) => const PaymentScreen(),
          '/promotions': (_) => const PromotionsScreen(),
          '/notifications': (_) => const NotificationsScreen(),
          '/support': (_) => const SupportScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/history': (_) => const HistoryScreen(),
          '/saved-addresses': (_) => const SavedAddressesScreen(),
          '/chat': (_) => const ChatScreen(),
          '/top-up': (_) => const TopUpScreen(),
          '/privacy': (_) => const PrivacyPolicyScreen(),
          '/terms': (_) => const TermsScreen(),

          // Food delivery
          '/food': (_) => const RestaurantListScreen(),
          '/restaurant-detail': (_) => const RestaurantDetailScreen(),
          '/checkout': (_) => const CheckoutScreen(),
          '/order-tracking': (_) => const OrderTrackingScreen(),
          '/order-detail': (_) => const OrderDetailScreen(),
          '/share-bill': (_) => const ShareBillScreen(),
        },
      ),
    );
  }
}
