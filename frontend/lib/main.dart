import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Comment out for Android build

import './services/api_service.dart';
import './providers/auth_provider.dart';
import './providers/vehicle_provider.dart';
import './providers/violation_provider.dart';
import './providers/analytics_provider.dart';
import './providers/notification_provider.dart';
import './providers/map_provider.dart';
import './providers/theme_provider.dart';
import './providers/tracking_provider.dart';
import './providers/violation_type_provider.dart';

import './screens/analytics_screen.dart';
import './screens/home_screen.dart';
import './screens/login_screen.dart';
import './screens/profile_screen.dart';
import './screens/register_screen.dart';
import './screens/vehicle_screen.dart';
import './screens/violation_screen.dart';
import './screens/camera_screen.dart';
import './screens/qr_scan_screen.dart';
import './screens/settings_screen.dart';
import './screens/payment_screen.dart';
import './screens/map_screen.dart';
import './screens/notification_screen.dart';
import './screens/violation_detail_screen.dart';
import './screens/officer_screen.dart';
import './screens/license_plate_scanner_screen.dart';
import './screens/violation_report_screen.dart';
import './screens/vehicle_violations_screen.dart';
import './screens/add_vehicle_screen.dart';
import './screens/violation_appeal_screen.dart';
import './screens/users_screen.dart';
import 'dart:async';

Future<void> main() async {
  // Comment out web-specific code
  // usePathUrlStrategy();
  
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // Display custom error UI instead of red screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  };

  // Catch errors not caught by Flutter framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('ERROR: ${details.exception}');
    debugPrint('STACK TRACE: ${details.stack}');
  };

  // Run app directly without zone
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
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => VehicleProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ViolationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MapProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TrackingProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ViolationTypeProvider(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                title: 'Smart Traffic Manager',
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: themeProvider.themeMode,
                home: authProvider.isAuthenticated
                    ? const HomeScreen()
                    : const LoginScreen(),
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/vehicle': (context) => const VehicleScreen(),
                  '/violations': (context) => const ViolationScreen(),
                  '/settings': (context) => const SettingsScreen(),
                  '/analytics': (context) => const AnalyticsScreen(),
                  '/map': (context) => const MapScreen(),
                  '/notifications': (context) => const NotificationScreen(),
                  '/officer': (context) => const OfficerScreen(),
                  '/license-plate-scanner': (context) => const LicensePlateScanner(),
                  '/report-violation': (context) => const ViolationReportScreen(),
                  '/users': (context) => const UsersScreen(),
                },
                onGenerateRoute: (settings) {
                  if (settings.name == '/login') {
                    return MaterialPageRoute(builder: (_) => const LoginScreen());
                  } else if (settings.name == '/register') {
                    return MaterialPageRoute(builder: (_) => const RegisterScreen());
                  } else if (settings.name == '/home') {
                    return MaterialPageRoute(builder: (_) => const HomeScreen());
                  } else if (settings.name == '/profile') {
                    return MaterialPageRoute(builder: (_) => const ProfileScreen());
                  } else if (settings.name == '/vehicles') {
                    return MaterialPageRoute(builder: (_) => const VehicleScreen());
                  } else if (settings.name == '/add-vehicle') {
                    return MaterialPageRoute(builder: (_) => const AddVehicleScreen());
                  } else if (settings.name == '/violations') {
                    return MaterialPageRoute(builder: (_) => const ViolationScreen());
                  } else if (settings.name == '/qr-scan') {
                    return MaterialPageRoute(builder: (_) => const QRScanScreen());
                  } else if (settings.name == '/violation-detail') {
                    final args = settings.arguments as Map<String, dynamic>;
                    final violationId = args['violationId'] as int;
                    return MaterialPageRoute(builder: (_) => ViolationDetailScreen(violationId: violationId));
                  } else if (settings.name == '/vehicle-violations') {
                    final args = settings.arguments as Map<String, dynamic>;
                    final vehicleId = args['vehicle_id'] as int;
                    final licensePlate = args['license_plate'] as String;
                    return MaterialPageRoute(builder: (_) => VehicleViolationsScreen(
                      vehicleId: vehicleId,
                      licensePlate: licensePlate,
                    ));
                  } else if (settings.name == '/payment') {
                    final args = settings.arguments as Map<String, dynamic>;
                    final violationId = args['violationId'] as int;
                    return MaterialPageRoute(builder: (_) => PaymentScreen(violationId: violationId));
                  } else if (settings.name == '/appeal') {
                    final args = settings.arguments as Map<String, dynamic>;
                    final violationId = args['violationId'] as int;
                    return MaterialPageRoute(builder: (_) => ViolationAppealScreen(violationId: violationId));
                  } else if (settings.name == '/camera') {
                    return MaterialPageRoute(builder: (_) => const CameraScreen());
                  } else if (settings.name == '/users') {
                    return MaterialPageRoute(builder: (_) => const UsersScreen());
                  }
                  return null;
                },
              );
            },
          );
        },
      ),
    );
  }
}
