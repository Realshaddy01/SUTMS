import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'storage_service.dart';
import 'api_service.dart';

class AuthService {
  final StorageService _storageService = StorageService();
  final _baseUrl = ApiService.baseUrl;
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Login user
  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login/'),
      headers: _headers,
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AuthResult.fromJson(data);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to login');
    }
  }

  // Register new user
  Future<AuthResult> register(String email, String password, String fullName, String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register/'),
      headers: _headers,
      body: json.encode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'user_type': 'vehicle_owner', // Default to vehicle owner
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return AuthResult.fromJson(data);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to register');
    }
  }

  // Logout user
  Future<bool> logout() async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      return true;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/logout/'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error during logout: $e');
      return false;
    }
  }

  // Get user profile
  Future<User> getUserProfile(String token) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    final response = await http.get(
      Uri.parse('$_baseUrl/users/profile/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return User.fromJson(data);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to get user profile');
    }
  }

  // Update user profile
  Future<User> updateProfile(Map<String, dynamic> userData) async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    final response = await http.patch(
      Uri.parse('$_baseUrl/users/update_profile/'),
      headers: headers,
      body: json.encode(userData),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return User.fromJson(data);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update profile');
    }
  }

  // Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/change_password/'),
      headers: headers,
      body: json.encode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    return response.statusCode == 200;
  }

  // Update FCM token
  Future<bool> updateFCMToken(String fcmToken) async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/update_fcm_token/'),
      headers: headers,
      body: json.encode({
        'fcm_token': fcmToken,
      }),
    );

    return response.statusCode == 200;
  }
}
