import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import '../utils/constants.dart';

class ApiClient {
  final String baseUrl;
  final StorageService _storageService = StorageService();
  
  ApiClient({required this.baseUrl});
  
  // Get authorization headers
  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (requireAuth) {
      final token = await _storageService.getAuthToken();
      if (token != null) {
        headers['Authorization'] = '${Constants.tokenPrefix} $token';
      }
    }
    
    return headers;
  }
  
  // Helper to handle errors consistently
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body);
    } else {
      var errorMessage = 'Error: ${response.statusCode}';
      try {
        final errorJson = json.decode(response.body);
        if (errorJson is Map) {
          if (errorJson.containsKey('error')) {
            errorMessage = errorJson['error'];
          } else if (errorJson.containsKey('message')) {
            errorMessage = errorJson['message'];
          } else if (errorJson.containsKey('detail')) {
            errorMessage = errorJson['detail'];
          }
        }
      } catch (e) {
        errorMessage = response.body;
      }
      throw Exception(errorMessage);
    }
  }
  
  // GET request
  Future<dynamic> get(String endpoint, {bool requireAuth = true, Map<String, dynamic>? queryParameters}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    
    final Uri uri = queryParameters != null
        ? Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters.map((key, value) => MapEntry(key, value.toString())))
        : Uri.parse('$baseUrl$endpoint');
    
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }
  
  // POST request
  Future<dynamic> post(String endpoint, {dynamic body, bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response);
  }
  
  // PUT request
  Future<dynamic> put(String endpoint, {dynamic body, bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response);
  }
  
  // PATCH request
  Future<dynamic> patch(String endpoint, {dynamic body, bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response);
  }
  
  // DELETE request
  Future<dynamic> delete(String endpoint, {bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _handleResponse(response);
  }
  
  // Upload file
  Future<dynamic> uploadFile(String endpoint, File file, {String fileField = 'file', Map<String, String>? fields, bool requireAuth = true}) async {
    final token = requireAuth ? await _storageService.getAuthToken() : null;
    
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    
    // Add auth header if needed
    if (requireAuth && token != null) {
      request.headers['Authorization'] = '${Constants.tokenPrefix} $token';
    }
    
    // Add file
    request.files.add(await http.MultipartFile.fromPath(
      fileField,
      file.path,
    ));
    
    // Add additional fields
    if (fields != null) {
      request.fields.addAll(fields);
    }
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }
  
  // Get with custom token
  Future<http.Response> getWithToken(String endpoint, String token, {Map<String, dynamic>? queryParameters}) async {
    final uri = Uri.parse('$baseUrl$endpoint')
        .replace(queryParameters: queryParameters);
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };
    
    return await http.get(uri, headers: headers);
  }
  
  // Post with custom token
  Future<http.Response> postWithToken(String endpoint, dynamic data, String token) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };
    
    return await http.post(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );
  }
  
  // Patch with custom token
  Future<http.Response> patchWithToken(String endpoint, dynamic data, String token) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };
    
    return await http.patch(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );
  }
  
  // Put with custom token
  Future<http.Response> putWithToken(String endpoint, dynamic data, String token) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };
    
    return await http.put(
      uri,
      headers: headers,
      body: jsonEncode(data),
    );
  }
  
  // Delete with custom token
  Future<http.Response> deleteWithToken(String endpoint, String token) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final headers = {
      'Accept': 'application/json',
      'Authorization': '${Constants.tokenPrefix} $token',
    };
    
    return await http.delete(uri, headers: headers);
  }
  
  // Upload file with custom token
  Future<http.Response> uploadFileWithToken(String endpoint, String filePath, String token, {Map<String, dynamic>? fields}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    request.headers['Authorization'] = '${Constants.tokenPrefix} $token';
    
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
}
