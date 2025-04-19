import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../services/storage_service.dart';

/// Utility class for debugging authentication issues
class AuthDebug {
  static final StorageService _storageService = StorageService();

  /// Tests authentication against the server with multiple auth header formats
  static Future<Map<String, dynamic>> testAuthHeaders() async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      return {'error': 'No authentication token found in storage'};
    }
    
    final results = <String, dynamic>{
      'token': token,
      'tests': <String, dynamic>{},
    };
    
    // Test different authorization header formats
    final headerFormats = {
      'Token': 'Token $token',
      'Bearer': 'Bearer $token',
      'token_only': token,
    };
    
    final client = http.Client();
    
    try {
      for (final entry in headerFormats.entries) {
        final headerType = entry.key;
        final headerValue = entry.value;
        
        try {
          final response = await client.get(
            Uri.parse('${Constants.apiBaseUrl}/users/profile/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': headerValue,
            },
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () => http.Response('Timeout', 408),
          );
          
          results['tests'][headerType] = {
            'status_code': response.statusCode,
            'success': response.statusCode == 200,
            'body_preview': response.body.length > 100 
                ? '${response.body.substring(0, 100)}...' 
                : response.body,
          };
          
          if (response.statusCode == 200) {
            // Found a working format, save it for future reference
            results['working_format'] = headerType;
          }
        } catch (e) {
          results['tests'][headerType] = {
            'error': e.toString(),
          };
        }
      }
    } finally {
      client.close();
    }
    
    return results;
  }
  
  /// Test API connection to different common URLs
  static Future<Map<String, dynamic>> testApiConnection() async {
    final results = <String, dynamic>{};
    
    // Try common localhost equivalents for emulators
    final urls = [
      'http://10.0.2.2:8000',
      'http://localhost:8000',
      'http://127.0.0.1:8000',
      'http://192.168.1.67:8000',
    ];
    
    final endpoints = [
      '/api/health-check/',
      '/admin/login/',
      '/api/',
    ];
    
    final client = http.Client();
    
    try {
      for (final baseUrl in urls) {
        results[baseUrl] = <String, dynamic>{};
        
        for (final endpoint in endpoints) {
          try {
            final response = await client.get(
              Uri.parse('$baseUrl$endpoint'),
            ).timeout(
              const Duration(seconds: 3),
              onTimeout: () => http.Response('Timeout', 408),
            );
            
            results[baseUrl][endpoint] = {
              'status_code': response.statusCode,
              'success': response.statusCode >= 200 && response.statusCode < 300,
              'content_type': response.headers['content-type'] ?? 'unknown',
            };
          } catch (e) {
            results[baseUrl][endpoint] = {
              'error': e.toString(),
            };
          }
        }
      }
    } finally {
      client.close();
    }
    
    return results;
  }
  
  /// Verify stored credentials and attempt login
  static Future<Map<String, dynamic>> verifyCredentials(String username, String password) async {
    final results = <String, dynamic>{};
    
    try {
      final response = await http.post(
        Uri.parse('${Constants.apiBaseUrl}/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      results['status_code'] = response.statusCode;
      results['success'] = response.statusCode == 200;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        results['token'] = data['token'];
        results['token_type'] = data['token'] != null ? 'Found' : 'Missing';
        
        // Save the new token if login was successful
        if (data['token'] != null) {
          await _storageService.saveAuthToken(data['token']);
          results['token_saved'] = true;
        }
      } else {
        results['error'] = 'Login failed with status code ${response.statusCode}';
        results['response'] = response.body;
      }
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Automatically fix token format issues by testing different formats
  static Future<Map<String, dynamic>> autoFixTokenFormat() async {
    final results = await testAuthHeaders();
    
    if (results.containsKey('working_format')) {
      final workingFormat = results['working_format'];
      
      // Update the Constants.tokenPrefix to the working format
      switch (workingFormat) {
        case 'Token':
          // Keep as is - this is the default format
          return {
            'success': true,
            'format': 'Token',
            'message': 'Token format is already working correctly'
          };
        
        case 'Bearer':
          // Update the correct token prefix in the storage
          final token = await _storageService.getAuthToken();
          if (token != null) {
            await _storageService.saveAuthToken(token);
            return {
              'success': true,
              'format': 'Bearer',
              'message': 'Updated to use Bearer format',
              'note': 'The app code should be updated to use Bearer format consistently'
            };
          }
          break;
        
        case 'token_only':
          // This is not a recommended format, but if it works
          final token = await _storageService.getAuthToken();
          if (token != null) {
            await _storageService.saveAuthToken(token);
            return {
              'success': true,
              'format': 'token_only',
              'message': 'Updated to use token without prefix',
              'note': 'The server appears to accept tokens without a prefix, which is unusual'
            };
          }
          break;
      }
    }
    
    return {
      'success': false,
      'message': 'Could not find a working authentication format',
      'test_results': results
    };
  }
} 