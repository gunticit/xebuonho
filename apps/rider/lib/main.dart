import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/location_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/trip_complete_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/promotions_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/support_screen.dart';
import 'screens/settings_screen.dart';

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
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/otp': (_) => const OtpScreen(),
          '/home': (_) => const HomeScreen(),
          '/search': (_) => const SearchScreen(),
          '/booking': (_) => const BookingScreen(),
          '/tracking': (_) => const TrackingScreen(),
          '/complete': (_) => const TripCompleteScreen(),
          '/history': (_) => const HistoryScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/payment': (_) => const PaymentScreen(),
          '/promotions': (_) => const PromotionsScreen(),
          '/notifications': (_) => const NotificationsScreen(),
          '/support': (_) => const SupportScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}
