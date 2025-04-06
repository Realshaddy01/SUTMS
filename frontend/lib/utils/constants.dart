/// Constants used throughout the application
class Constants {
  // API URL
  static const String apiBaseUrl = 'http://0.0.0.0:5000/api';
  static const String wsBaseUrl = 'ws://0.0.0.0:5000/ws';
  
  // Authentication
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  
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
