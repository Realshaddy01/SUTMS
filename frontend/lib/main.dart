import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sutms_flutter/services/api_service.dart';
import 'package:sutms_flutter/providers/auth_provider.dart';
import 'package:sutms_flutter/providers/vehicle_provider.dart';
import 'package:sutms_flutter/providers/violation_provider.dart';
import 'package:sutms_flutter/providers/payment_provider.dart';
import 'package:sutms_flutter/providers/analytics_provider.dart';
import 'package:sutms_flutter/screens/analytics_screen.dart';
import 'package:sutms_flutter/screens/dashboard_screen.dart';
import 'package:sutms_flutter/screens/login_screen.dart';
import 'package:sutms_flutter/screens/profile_screen.dart';
import 'package:sutms_flutter/screens/register_screen.dart';
import 'package:sutms_flutter/screens/splash_screen.dart';
import 'package:sutms_flutter/screens/vehicle_screen.dart';
import 'package:sutms_flutter/screens/violations_screen.dart';
import 'package:sutms_flutter/screens/ocr_screen.dart';
import 'package:sutms_flutter/screens/qr_scanner_screen.dart';
import 'package:sutms_flutter/screens/settings_screen.dart';
import 'package:sutms_flutter/screens/payments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Comment out Firebase initialization for web testing
  // await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ApiService apiService = ApiService();

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => VehicleProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ViolationProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => PaymentProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(apiService: apiService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'Smart Urban Traffic Management System',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              appBarTheme: const AppBarTheme(
                elevation: 0,
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              cardTheme: CardTheme(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            home: authProvider.isInitializing
                ? const SplashScreen()
                : authProvider.isAuthenticated
                    ? const DashboardScreen()
                    : const LoginScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/vehicles': (context) => const VehicleScreen(),
              '/violations': (context) => const ViolationsScreen(),
              '/all-violations': (context) => const ViolationsScreen(showAll: true),
              '/ocr': (context) => const OcrScreen(),
              '/qr-scanner': (context) => const QrScannerScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/payments': (context) => const PaymentsScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
            },
          );
        },
      ),
    );
  }
}
