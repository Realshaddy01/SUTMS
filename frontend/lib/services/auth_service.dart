import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/auth_result.dart';
import 'storage_service.dart';
import '../utils/constants.dart';

class AuthService {
  final StorageService _storageService = StorageService();
  final String _baseUrl = Constants.apiBaseUrl;
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Login user
  Future<AuthResult> login(String emailOrUsername, String password) async {
    try {
      // Determine if input is email or username
      bool isEmail = emailOrUsername.contains('@');
      
      final Map<String, dynamic> loginData = {
        'password': password,
      };
      
      // Send both fields to be compatible with different backends
      if (isEmail) {
        loginData['email'] = emailOrUsername;
        loginData['username'] = emailOrUsername;  // Backend will handle email-as-username
      } else {
        loginData['username'] = emailOrUsername;
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login/'),
        headers: _headers,
        body: json.encode(loginData),
      );

      // Print response for debugging
      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body.substring(0, min(100, response.body.length))}...');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AuthResult.fromJson(data);
      } else {
        // Try to parse JSON error
        try {
          final error = json.decode(response.body);
          throw Exception(error);
        } catch (e) {
          // If it's not valid JSON (e.g., HTML response), throw a more helpful error
          if (response.body.contains('<!DOCTYPE')) {
            throw Exception('Server error: The server returned an HTML page instead of JSON. Please check your server configuration.');
          } else {
            throw Exception('Failed to login: Status ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Register new user
  Future<AuthResult> register(String email, String password, String fullName, String phoneNumber, {
    String? username,
    String? firstName,
    String? lastName,
    String? userType,
    String? citizenshipNumber,
    String? address,
    String? badgeNumber,
    String? department,
  }) async {
    // Split full name into first and last name if not provided
    if (firstName == null || lastName == null) {
      final nameParts = fullName.split(' ');
      firstName = nameParts[0];
      lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    }

    final Map<String, dynamic> data = {
      'email': email,
      'password': password,
      'confirm_password': password,
      'username': username ?? email.split('@')[0],
      'first_name': firstName,
      'last_name': lastName,
      'user_type': userType ?? 'vehicle_owner',
      'phone_number': phoneNumber,
    };

    if (citizenshipNumber != null) data['citizenship_number'] = citizenshipNumber;
    if (address != null) data['address'] = address;
    if (badgeNumber != null) data['badge_number'] = badgeNumber;
    if (department != null) data['department'] = department;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register/'),
        headers: _headers,
        body: json.encode(data),
      );

      // Print response for debugging
      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body.substring(0, min(100, response.body.length))}...');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return AuthResult.fromJson(responseData);
      } else {
        // Try to parse JSON error
        try {
          final error = json.decode(response.body);
          throw Exception(error);
        } catch (e) {
          // If it's not valid JSON (e.g., HTML response), throw a more helpful error
          if (response.body.contains('<!DOCTYPE')) {
            throw Exception('Server error: The server returned an HTML page instead of JSON. Please check your server configuration.');
          } else {
            throw Exception('Failed to register: Status ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
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
      'Authorization': '${Constants.tokenPrefix} $token',
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
      'Authorization': '${Constants.tokenPrefix} $token',
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
      'Authorization': '${Constants.tokenPrefix} $token',
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
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/change-password/'),
      headers: headers,
      body: json.encode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to change password');
    }
  }

  // Update FCM token
  Future<bool> updateFCMToken(String fcmToken) async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/update_fcm_token/'),
      headers: headers,
      body: json.encode({
        'fcm_token': fcmToken,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update FCM token');
    }
  }
}
