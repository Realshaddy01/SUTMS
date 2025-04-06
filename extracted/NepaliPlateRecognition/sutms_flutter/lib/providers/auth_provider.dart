import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  
  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  
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
      final token = await _storageService.getAuthToken();
      if (token != null) {
        // Validate token and get user info
        final userData = await _authService.getUserProfile(token);
        _user = userData;
        _isAuthenticated = true;
      }
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      await _storageService.clearAuthToken();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Login method
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _authService.login(email, password);
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
  
  // Register method
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
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
