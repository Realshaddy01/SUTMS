import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../models/notification.dart';
import '../models/analytics_data.dart';

class ApiService {
  // Singleton instance
  static final ApiService instance = ApiService._internal();

  // Authentication state
  bool _isAuthenticated = false;
  String? _token;
  String? _refreshToken;
  String? _userRole;
  int? _userId;
  String? _username;
  
  // WebSocket connections
  dynamic _trackingChannel;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userRole => _userRole;
  int? get userId => _userId;
  String? get username => _username;

  // Factory constructor
  factory ApiService() {
    return instance;
  }

  // Private constructor
  ApiService._internal();

  // Initialize the service (load saved tokens)
  Future<void> init() async {
    await _loadAuthData();
  }

  // Load authentication data from storage
  Future<void> _loadAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(Constants.tokenKey);
      _refreshToken = prefs.getString(Constants.refreshTokenKey);
      _userRole = prefs.getString(Constants.userRoleKey);
      
      if (_token != null && _token!.isNotEmpty) {
        _isAuthenticated = true;
        // TODO: Validate token by making a request to /api/auth/user/
      }
    } catch (e) {
      print('Error loading auth data: $e');
      _clearAuthData();
    }
  }

  // Save authentication data to storage
  Future<void> _saveAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) await prefs.setString(Constants.tokenKey, _token!);
      if (_refreshToken != null) await prefs.setString(Constants.refreshTokenKey, _refreshToken!);
      if (_userRole != null) await prefs.setString(Constants.userRoleKey, _userRole!);
    } catch (e) {
      print('Error saving auth data: $e');
    }
  }

  // Clear authentication data
  Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(Constants.tokenKey);
      await prefs.remove(Constants.refreshTokenKey);
      await prefs.remove(Constants.userRoleKey);
      
      _token = null;
      _refreshToken = null;
      _userRole = null;
      _userId = null;
      _username = null;
      _isAuthenticated = false;
    } catch (e) {
      print('Error clearing auth data: $e');
    }
  }

  // Set authentication data after successful login/registration
  Future<void> setAuthData(Map<String, dynamic> data) async {
    _token = data['token'];
    _refreshToken = data['refresh_token'];
    _userRole = data['user']['role'];
    _userId = data['user']['id'];
    _username = data['user']['username'];
    _isAuthenticated = true;
    
    await _saveAuthData();
    
    // Connect to WebSocket for real-time updates if authenticated
    connectToWebSocket();
  }
  
  // Logout and clear auth data
  Future<void> logout() async {
    // Disconnect from WebSocket
    _trackingChannel = null;
    
    // Clear auth data
    await _clearAuthData();
  }

  // Get HTTP headers with authentication token
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_token != null) {
      headers['Authorization'] = 'Token $_token';
    }
    
    return headers;
  }

  // Login with username and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${Constants.apiBaseUrl}/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await setAuthData(data);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['non_field_errors'] ?? 'Login failed');
    }
  }

  // Register a new user
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('${Constants.apiBaseUrl}/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await setAuthData(data);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['non_field_errors'] ?? 'Registration failed');
    }
  }

  // Generic GET request
  Future<http.Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint')
        .replace(queryParameters: queryParameters);
    
    final response = await http.get(
      uri,
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      await _refreshAuthToken();
      
      // Retry the request with the new token
      return await http.get(
        uri,
        headers: _getHeaders(),
      );
    }
    
    return response;
  }

  // Generic POST request
  Future<http.Response> post(String endpoint, dynamic data) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final response = await http.post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      await _refreshAuthToken();
      
      // Retry the request with the new token
      return await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(data),
      );
    }
    
    return response;
  }

  // Generic PUT request
  Future<http.Response> put(String endpoint, dynamic data) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final response = await http.put(
      uri,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      await _refreshAuthToken();
      
      // Retry the request with the new token
      return await http.put(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(data),
      );
    }
    
    return response;
  }

  // Generic PATCH request
  Future<http.Response> patch(String endpoint, dynamic data) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final response = await http.patch(
      uri,
      headers: _getHeaders(),
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      await _refreshAuthToken();
      
      // Retry the request with the new token
      return await http.patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(data),
      );
    }
    
    return response;
  }

  // Generic DELETE request
  Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final response = await http.delete(
      uri,
      headers: _getHeaders(),
    );
    
    if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      await _refreshAuthToken();
      
      // Retry the request with the new token
      return await http.delete(
        uri,
        headers: _getHeaders(),
      );
    }
    
    return response;
  }

  // Refresh authentication token
  Future<void> _refreshAuthToken() async {
    if (_refreshToken == null) {
      // No refresh token available, force logout
      await logout();
      throw Exception('Session expired, please login again');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh': _refreshToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access'];
        await _saveAuthData();
      } else {
        // Refresh token is invalid or expired, force logout
        await logout();
        throw Exception('Session expired, please login again');
      }
    } catch (e) {
      await logout();
      throw Exception('Session expired, please login again');
    }
  }
  
  // Upload an image file
  Future<http.Response> uploadImage(String endpoint, File imageFile, {String fieldName = 'image'}) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_getHeaders());
    request.files.add(await http.MultipartFile.fromPath(fieldName, imageFile.path));
    
    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
  
  // Detect license plate from image
  Future<Map<String, dynamic>> detectLicensePlateWithoutToken(File imageFile) async {
    try {
      // Upload image to server for license plate detection
      final response = await uploadImage('ocr/api/detect/', imageFile);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to detect license plate');
      }
    } catch (e) {
      print('Error during license plate detection: $e');
      throw Exception('License plate detection failed: $e');
    }
  }
  
  // Connect to WebSocket for real-time tracking data - simplified version
  void connectToWebSocket() {
    if (!_isAuthenticated || _token == null) return;
    
    print('WebSocket functionality is currently disabled.');
    // Implementation will be added when WebSocket package is properly configured
  }
  
  // Get tracking data via WebSocket - simplified version
  void requestTrackingData(String action) {
    if (_trackingChannel != null) {
      print('WebSocket functionality is currently disabled.');
      // Implementation will be added when WebSocket package is properly configured
    }
  }

  // Get notifications for the current user
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await get('notifications/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => NotificationModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print('Error getting notifications: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }
  
  // Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await get('notifications/unread-count/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        throw Exception('Failed to load unread notification count');
      }
    } catch (e) {
      print('Error getting unread count: $e');
      throw Exception('Failed to load unread notification count: $e');
    }
  }
  
  // Mark a notification as read
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await patch('notifications/$notificationId/read/', {});
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }
  
  // Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await post('notifications/mark-all-read/', {});
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Get analytics data
  Future<AnalyticsData> getAnalyticsData(String period) async {
    try {
      final response = await get(
        'analytics/',
        queryParameters: {'period': period},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AnalyticsData.fromJson(data);
      } else {
        throw Exception('Failed to get analytics data');
      }
    } catch (e) {
      print('Error getting analytics data: $e');
      throw Exception('Failed to get analytics data: $e');
    }
  }

  // Create a checkout session for payment
  Future<Map<String, dynamic>> createCheckoutSession(int violationId) async {
    try {
      final response = await post(
        'payments/create-checkout-session/',
        {'violation_id': violationId},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create checkout session');
      }
    } catch (e) {
      print('Error creating checkout session: $e');
      throw Exception('Failed to create checkout session: $e');
    }
  }

  // Verify QR Code
  Future<Map<String, dynamic>> verifyQRCode(String qrData) async {
    try {
      final response = await post(
        'vehicles/verify-qr/',
        {'qr_data': qrData},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to verify QR code');
      }
    } catch (e) {
      print('Error verifying QR code: $e');
      throw Exception('Failed to verify QR code: $e');
    }
  }

  // Set the authentication token temporarily (without saving to storage)
  void setTemporaryToken(String token) {
    _token = token;
    _isAuthenticated = true;
  }
  
  // Clear the temporary token
  void clearTemporaryToken() {
    if (_refreshToken == null) {
      // Only clear if it was a temporary token (no refresh token)
      _token = null;
      _isAuthenticated = false;
    }
  }
  
  // Get with custom token
  Future<http.Response> getWithToken(String endpoint, String token, {Map<String, dynamic>? queryParameters}) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint')
        .replace(queryParameters: queryParameters);
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    };
    
    return await http.get(uri, headers: headers);
  }
  
  // Post with custom token
  Future<http.Response> postWithToken(String endpoint, dynamic data, String token) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    };
    
    return await http.post(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );
  }
  
  // Patch with custom token
  Future<http.Response> patchWithToken(String endpoint, dynamic data, String token) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    };
    
    return await http.patch(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );
  }
  
  // Put with custom token
  Future<http.Response> putWithToken(String endpoint, dynamic data, String token) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    };
    
    return await http.put(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );
  }
  
  // Delete with custom token
  Future<http.Response> deleteWithToken(String endpoint, String token) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Token $token',
    };
    
    return await http.delete(uri, headers: headers);
  }
  
  // Upload file with custom token
  Future<http.Response> uploadFileWithToken(String endpoint, String filePath, String token, {Map<String, dynamic>? fields}) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/$endpoint');
    
    final request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    request.headers['Authorization'] = 'Token $token';
    
    // Add file
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    
    // Add other fields
    if (fields != null) {
      fields.forEach((key, value) {
        request.fields[key] = value.toString();
      });
    }
    
    // Send the request
    final streamedResponse = await request.send();
    
    // Convert to Response
    return await http.Response.fromStream(streamedResponse);
  }

  /// Scan license plate image
  Future<Map<String, dynamic>> scanLicensePlate(File imageFile, {bool hasInternet = true}) async {
    try {
      String url = '${Constants.apiBaseUrl}/api/scan-license-plate/';
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add authorization token
      request.headers['Authorization'] = 'Bearer $_token';
      
      // Add internet availability flag
      request.fields['internet_available'] = hasInternet.toString();
      
      // Add image file to request
      var pic = await http.MultipartFile.fromPath('image', imageFile.path);
      request.files.add(pic);
      
      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to scan license plate: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error scanning license plate: $e');
    }
  }
  
  /// Get list of violation types for dropdowns
  Future<List<Map<String, dynamic>>> getViolationTypes() async {
    try {
      var response = await get('violation-types/');
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load violation types');
      }
    } catch (e) {
      throw Exception('Error loading violation types: $e');
    }
  }
  
  /// Report a new violation
  Future<Map<String, dynamic>> reportViolation({
    required int vehicleId,
    required int violationTypeId,
    required String location,
    required String description,
    double? latitude,
    double? longitude,
    File? evidenceImage,
    File? licensePlateImage,
  }) async {
    try {
      String url = '${Constants.apiBaseUrl}/api/report-violation/';
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add authorization token
      request.headers['Authorization'] = 'Bearer $_token';
      
      // Add fields
      request.fields['vehicle_id'] = vehicleId.toString();
      request.fields['violation_type_id'] = violationTypeId.toString();
      request.fields['location'] = location;
      request.fields['description'] = description;
      
      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }
      
      // Add evidence image if provided
      if (evidenceImage != null) {
        var evidenceFile = await http.MultipartFile.fromPath('evidence_image', evidenceImage.path);
        request.files.add(evidenceFile);
      }
      
      // Add license plate image if provided
      if (licensePlateImage != null) {
        var plateFile = await http.MultipartFile.fromPath('license_plate_image', licensePlateImage.path);
        request.files.add(plateFile);
      }
      
      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to report violation: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error reporting violation: $e');
    }
  }
  
  /// Get vehicle violations with optional date filters
  Future<Map<String, dynamic>> getVehicleViolations(
    int vehicleId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = 'vehicle/$vehicleId/violations/';
      
      // Add query parameters if provided
      if (startDate != null || endDate != null) {
        List<String> queryParams = [];
        
        if (startDate != null) {
          queryParams.add('start_date=$startDate');
        }
        
        if (endDate != null) {
          queryParams.add('end_date=$endDate');
        }
        
        url += '?${queryParams.join('&')}';
      }
      
      var response = await getWithToken(url, _token ?? '');
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Error getting vehicle violations: $e');
    }
  }
  
  /// Submit appeal for a violation
  Future<Map<String, dynamic>> submitViolationAppeal({
    required String token,
    required int violationId,
    required String reason,
    File? evidenceFile,
  }) async {
    try {
      // Create the URL for the appeal endpoint
      String url = '${Constants.apiBaseUrl}/violation-appeals/';
      
      // Create multipart request if there's an evidence file
      if (evidenceFile != null) {
        var request = http.MultipartRequest('POST', Uri.parse(url));
        
        // Add authorization token
        request.headers['Authorization'] = 'Token $token';
        
        // Add fields
        request.fields['violation'] = violationId.toString();
        request.fields['reason'] = reason;
        
        // Add evidence file if provided
        var file = await http.MultipartFile.fromPath('evidence_file', evidenceFile.path);
        request.files.add(file);
        
        // Send request
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 201) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to submit appeal: ${response.body}');
        }
      } else {
        // Simple JSON request if no file
        final response = await postWithToken(
          'violation-appeals/',
          {
            'violation': violationId,
            'reason': reason,
          },
          token,
        );
        
        if (response.statusCode == 201) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to submit appeal: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error submitting appeal: $e');
    }
  }

  // License plate detection
  Future<Map<String, dynamic>> detectLicensePlate(File imageFile, String token) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/api/detect-license-plate/');
    
    // Create multipart request
    var request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    request.headers['Authorization'] = 'Token $token';
    
    // Add file to request
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    ));
    
    // Send request
    var response = await request.send();
    
    // Check if successful
    if (response.statusCode == 200) {
      // Parse response
      var responseData = await response.stream.bytesToString();
      return json.decode(responseData);
    } else {
      // Handle error
      var responseData = await response.stream.bytesToString();
      var error = json.decode(responseData);
      throw Exception(error['error'] ?? 'Failed to detect license plate');
    }
  }
  
  // Vehicle lookup by license plate
  Future<Map<String, dynamic>> lookupVehicleByPlate(String licensePlate, String token) async {
    final uri = Uri.parse('${Constants.apiBaseUrl}/api/lookup-vehicle/');
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: json.encode({'license_plate': licensePlate}),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      var error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to lookup vehicle');
    }
  }
}
