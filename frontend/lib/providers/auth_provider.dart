import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  String? _token;
  
  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  // String get userType => _user?.userType ?? 'vehicle_owner';
  String get userType => user?.userType ?? 'vehicle_owner';
  String? get token => _token;
  
  // Services
  final _authService = AuthService();
  final _storageService = StorageService();
  
  // Constructor checks for existing token
  AuthProvider() {
    checkAuthStatus();
  }
  
  // Check if user is already authenticated
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Get token from storage
      final token = await _storageService.getAuthToken();
      if (token != null) {
        _token = token;
        // Validate token and get user info
        try {
          final userData = await _authService.getUserProfile(token);
          _user = userData;
          _isAuthenticated = true;
          print("Successfully authenticated with saved token: $token");
        } catch (e) {
          print("Failed to get user profile with token, clearing: $e");
          await _storageService.clearAuthToken();
          _token = null;
        }
      }
    } catch (e) {
      print('Auth status check error: $e');
      _error = e.toString();
      _isAuthenticated = false;
      await _storageService.clearAuthToken();
      _token = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Login method
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _authService.login(email, password);
      _user = result.user;
      _token = result.token;
      
      // Save token immediately
      if (_token != null) {
        await _storageService.saveAuthToken(_token!);
        print("Saved auth token: $_token");
      }
      
      _isAuthenticated = true;
      _error = null;
      notifyListeners();
      
      // Add debug output
      print("Login successful: User=${_user?.username}, Token=$_token");
      return true;
    } catch (e) {
      // Handle validation errors
      if (e.toString().contains('{')) {
        try {
          final errorStr = e.toString().replaceAll('Exception: ', '');
          final errorMap = json.decode(errorStr);
          final errors = <String>[];
          errorMap.forEach((key, value) {
            if (value is List) {
              errors.add('${key.toUpperCase()}: ${value.join(', ')}');
            } else {
              errors.add('${key.toUpperCase()}: $value');
            }
          });
          _error = errors.join('\n');
        } catch (_) {
          _error = e.toString();
        }
      } else {
        _error = e.toString();
      }
      _isAuthenticated = false;
      notifyListeners();
      
      // Add debug output
      print("Login failed: $_error");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Simple register method
  Future<bool> register(String email, String password, String fullName, String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _authService.register(email, password, fullName, phoneNumber);
      _user = result.user;
      await _storageService.saveAuthToken(result.token);
      _isAuthenticated = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Register method with all parameters
  Future<bool> registerFull({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String userType,
    String? citizenshipNumber,
    String? phoneNumber,
    String? address,
    String? badgeNumber,
    String? department,
    String? jurisdiction,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _authService.register(
        email,
        password,
        '$firstName $lastName',
        phoneNumber ?? '',
        username: username,
        firstName: firstName,
        lastName: lastName,
        userType: userType,
        citizenshipNumber: citizenshipNumber,
        address: address,
        badgeNumber: badgeNumber,
        department: department,
      );
      
      _user = result.user;
      await _storageService.saveAuthToken(result.token);
      _isAuthenticated = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      // Handle validation errors
      if (e.toString().contains('{')) {
        try {
          final errorStr = e.toString().replaceAll('Exception: ', '');
          final errorMap = json.decode(errorStr);
          final errors = <String>[];
          errorMap.forEach((key, value) {
            if (value is List) {
              errors.add('${key.toUpperCase()}: ${value.join(', ')}');
            } else {
              errors.add('${key.toUpperCase()}: $value');
            }
          });
          _error = errors.join('\n');
        } catch (_) {
          _error = e.toString();
        }
      } else {
        _error = e.toString();
      }
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update profile - matches AuthService.updateProfile(Map<String, dynamic>)
  Future<User?> updateProfile({
    String? email,
    String? fullName,
    String? phoneNumber,
    String? address,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Create a map with the provided data
      final Map<String, dynamic> userData = {};
      if (email != null) userData['email'] = email;
      if (fullName != null) userData['full_name'] = fullName;
      if (phoneNumber != null) userData['phone_number'] = phoneNumber;
      if (address != null) userData['address'] = address;
      
      final updatedUser = await _authService.updateProfile(userData);
      _user = updatedUser;
      _error = null;
      notifyListeners();
      return updatedUser;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Change password - matches AuthService.changePassword(String, String)
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authService.changePassword(currentPassword, newPassword);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Logout method
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.logout();
      await _storageService.clearAuthToken();
      _user = null;
      _isAuthenticated = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update FCM token
  Future<void> updateFCMToken(String fcmToken) async {
    if (_user != null && _isAuthenticated) {
      try {
        await _authService.updateFCMToken(fcmToken);
      } catch (e) {
        _error = e.toString();
        notifyListeners();
      }
    }
  }
}
