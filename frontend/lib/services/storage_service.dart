import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Key constants
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userDataKey = 'user_data';
  
  // Get authentication token
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: Constants.tokenKey);
  }
  
  // Save authentication token
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: Constants.tokenKey, value: token);
  }
  
  // Clear authentication token (logout)
  Future<void> clearAuthToken() async {
    await _secureStorage.delete(key: Constants.tokenKey);
  }
  
  // Save user ID
  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }
  
  // Get user ID
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }
  
  // Save user data
  Future<void> saveUserData(String userData) async {
    await _secureStorage.write(key: Constants.userDataKey, value: userData);
  }
  
  // Get user data
  Future<String?> getUserData() async {
    return await _secureStorage.read(key: Constants.userDataKey);
  }
  
  // Clear all user data
  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  // Save setting
  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }
  
  // Get setting as String
  Future<String?> getStringSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
  
  // Get setting as int
  Future<int?> getIntSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }
  
  // Get setting as bool
  Future<bool?> getBoolSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }
  
  // Get setting as double
  Future<double?> getDoubleSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key);
  }
  
  // Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: Constants.refreshTokenKey, value: token);
  }
  
  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: Constants.refreshTokenKey);
  }
  
  // Save user role
  Future<void> saveUserRole(String role) async {
    await _secureStorage.write(key: Constants.userRoleKey, value: role);
  }
  
  // Get user role
  Future<String?> getUserRole() async {
    return await _secureStorage.read(key: Constants.userRoleKey);
  }
}
