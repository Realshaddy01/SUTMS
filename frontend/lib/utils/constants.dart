import 'package:http/http.dart' as http;

/// Constants used throughout the application
class Constants {
  // API URL - Using your computer's actual IP address for physical device connection
  // static const String apiBaseUrl = 'http://10.0.2.2:8000/api'; // Use localhost equivalent for emulators
  static const String apiBaseUrl = 'http://192.168.1.67:8000/api'; // Use localhost equivalent for emulators
  static const String wsBaseUrl = 'ws://192.168.1.67:8000/ws';

  
  
  // Authentication
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userDataKey = 'user_data';
  static const String tokenPrefix = 'Token'; // Consistent token prefix (Token or Bearer)
  
  // Helper methods for auth
  static Map<String, String> getAuthHeader(String token) {
    return {'Authorization': '$tokenPrefix $token'};
  }
  
  static Map<String, String> getContentTypeJsonAuthHeader(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '$tokenPrefix $token',
    };
  }
  
  // Debug helper for connection issues
  static Future<String> debugApiConnection() async {
    try {
      // Try common localhost equivalents for emulators
      final urls = [
        'http://10.0.2.2:8000/api',  // Android emulator
        'http://localhost:8000/api',  // iOS simulator
        'http://127.0.0.1:8000/api',  // Direct localhost
      ];
      
      final client = http.Client();
      final results = <String>[];
      
      for (final url in urls) {
        try {
          final response = await client.get(Uri.parse('$url/health-check/')).timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('Timeout', 408),
          );
          results.add('$url: ${response.statusCode}');
        } catch (e) {
          results.add('$url: Error - $e');
        }
      }
      
      client.close();
      return results.join('\n');
    } catch (e) {
      return 'Error during connection test: $e';
    }
  }
  
  // Map
  static const double defaultMapZoom = 14.0;
  static const double nearbyRadius = 5.0; // km
  
  // Location tracking
  static const int locationUpdateInterval = 10; // seconds
  static const double locationMinDistance = 10.0; // meters
  
  // WebSocket
  static const int reconnectInterval = 3000; // ms
  static const int maxReconnectAttempts = 5;
  
  // UI
  static const double appBarElevation = 4.0;
  static const double cardElevation = 2.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Color keys - these should match with the colors in theme.dart
  static const String primaryColorKey = 'primary';
  static const String secondaryColorKey = 'secondary';
  static const String accentColorKey = 'accent';
  
  // Violation status
  static const String statusPending = 'pending';
  static const String statusPaid = 'paid';
  static const String statusDisputed = 'disputed';
  static const String statusCancelled = 'cancelled';
  
  // User roles
  static const String roleUser = 'user';
  static const String roleOfficer = 'officer';
  static const String roleAdmin = 'admin';
  
  // Periods for analytics
  static const String periodToday = 'today';
  static const String periodWeek = 'week';
  static const String periodMonth = 'month';
  static const String periodYear = 'year';
  static const String periodAll = 'all';
}
