import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/constants.dart';

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
  WebSocketChannel? _trackingChannel;
  
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
    _trackingChannel?.sink.close();
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
  Future<Map<String, dynamic>> login(String username, String password) async {
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
      Uri.parse('${Constants.apiBaseUrl}/auth/registration/'),
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
  Future<Map<String, dynamic>> detectLicensePlate(File imageFile) async {
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
  
  // Connect to WebSocket for real-time tracking data
  void connectToWebSocket() {
    if (!_isAuthenticated || _token == null) return;
    
    // Close existing connection if any
    _trackingChannel?.sink.close();
    
    // Create new connection
    try {
      _trackingChannel = IOWebSocketChannel.connect(
        '${Constants.wsBaseUrl}/tracking/',
        headers: {
          'Authorization': 'Token $_token',
        },
      );
      
      print('Connected to tracking WebSocket');
      
      // Request initial data
      _trackingChannel?.sink.add(jsonEncode({
        'action': 'get_all_tracking_data'
      }));
      
      // Listen for incoming messages
      _trackingChannel?.stream.listen(
        (message) {
          // Process received data
          final data = jsonDecode(message);
          print('Received WebSocket data: ${data['type']}');
          
          // TODO: Notify appropriate providers about the data update
        },
        onError: (error) {
          print('WebSocket error: $error');
          // Attempt to reconnect after a delay
          Future.delayed(Duration(milliseconds: Constants.reconnectInterval), () {
            connectToWebSocket();
          });
        },
        onDone: () {
          print('WebSocket connection closed');
          // Attempt to reconnect after a delay
          Future.delayed(Duration(milliseconds: Constants.reconnectInterval), () {
            connectToWebSocket();
          });
        },
      );
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
      // Attempt to reconnect after a delay
      Future.delayed(Duration(milliseconds: Constants.reconnectInterval), () {
        connectToWebSocket();
      });
    }
  }
  
  // Get tracking data via WebSocket
  void requestTrackingData(String action) {
    if (_trackingChannel != null) {
      _trackingChannel!.sink.add(jsonEncode({
        'action': action
      }));
    }
  }
}
