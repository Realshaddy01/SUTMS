class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // For Android emulator
  // static const String baseUrl = 'http://127.0.0.1:8000/api'; // For iOS simulator
  
  // Endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String profile = '/auth/profile/';
  static const String violations = '/violations/';
  static const String reportViolation = '/violations/report/';
  static const String scanQr = '/vehicles/scan/';
}

