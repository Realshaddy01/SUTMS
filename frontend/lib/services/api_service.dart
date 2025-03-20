import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutms/utils/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _token;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: dotenv.get('API_URL', fallback: ApiConstants.baseUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_token != null) {
          options.headers['Authorization'] = 'Token $_token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle token expiration
          _logout();
        }
        return handler.next(error);
      },
    ));
    
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // General request method
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // Authentication APIs
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.register, data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(ApiConstants.login, data: {
        'username': username,
        'password': password,
      });
      
      if (response.data['token'] != null) {
        await setToken(response.data['token']);
      }
      
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.login);
      await _logout();
    } catch (e) {
      await _logout();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get(ApiConstants.profile);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(ApiConstants.profile, data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateFCMToken(String fcmToken) async {
    try {
      await _dio.post('/auth/fcm-token/', data: {'fcm_token': fcmToken});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Vehicle APIs
  Future<List<dynamic>> getVehicles() async {
    try {
      final response = await _dio.get('/vehicles/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getVehicle(int id) async {
    try {
      final response = await _dio.get('/vehicles/$id/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/vehicles/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateVehicle(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/vehicles/$id/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteVehicle(int id) async {
    try {
      await _dio.delete('/vehicles/$id/');
    } catch (e) {
      rethrow;
    }
  }

  // Violation APIs
  Future<List<dynamic>> getViolations() async {
    try {
      final response = await _dio.get('/violations/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getViolation(int id) async {
    try {
      final response = await _dio.get('/violations/$id/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> reportViolation(Map<String, dynamic> data, File? evidenceImage) async {
    try {
      FormData formData = FormData.fromMap(data);
      
      if (evidenceImage != null) {
        formData.files.add(
          MapEntry(
            'evidence_image',
            await MultipartFile.fromFile(evidenceImage.path),
          ),
        );
      }
      
      final response = await _dio.post('/violations/', data: formData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> confirmViolation(int id) async {
    try {
      await _dio.post('/violations/$id/confirm/');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> payViolation(int id) async {
    try {
      await _dio.post('/violations/$id/pay/');
    } catch (e) {
      rethrow;
    }
  }

  // Appeals APIs
  Future<List<dynamic>> getViolationAppeals() async {
    try {
      final response = await _dio.get('/violation-appeals/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitAppeal(Map<String, dynamic> data, File? evidenceImage) async {
    try {
      FormData formData = FormData.fromMap(data);
      
      if (evidenceImage != null) {
        formData.files.add(
          MapEntry(
            'evidence_image',
            await MultipartFile.fromFile(evidenceImage.path),
          ),
        );
      }
      
      final response = await _dio.post('/violation-appeals/', data: formData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reviewAppeal(int id, String status, String comments) async {
    try {
      await _dio.post('/violation-appeals/$id/review/', data: {
        'status': status,
        'comments': comments,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Detection APIs
  Future<Map<String, dynamic>> detectNumberPlate(File image) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path),
      });
      
      final response = await _dio.post('/detection/number-plate/', data: formData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> processVideo(
    File video, 
    List<String> violationTypes
  ) async {
    try {
      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(video.path),
        'violation_types': violationTypes,
      });
      
      final response = await _dio.post('/detection/process-video/', data: formData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> reportDetectionViolation(
    String token,
    String detectionId,
    String location,
    File? evidenceImage,
    String numberPlate,
    String violationType,
  ) async {
    try {
      FormData formData = FormData.fromMap({
        'detection_id': detectionId,
        'location': location,
        'number_plate': numberPlate,
        'violation_type': violationType,
      });
      
      if (evidenceImage != null) {
        formData.files.add(
          MapEntry(
            'evidence_image',
            await MultipartFile.fromFile(evidenceImage.path),
          ),
        );
      }
      
      final response = await _dio.post(
        '/detection/report-violation/',
        data: formData,
      );
      
      return response.data['success'] ?? false;
    } catch (e) {
      rethrow;
    }
  }

  // Payment APIs
  Future<Map<String, dynamic>> createPaymentIntent(
    String amount,
    String currency,
    int violationId,
  ) async {
    try {
      final response = await _dio.post(
        '/payments/create-payment-intent/',
        data: {
          'amount': amount,
          'currency': currency,
          'violation_id': violationId,
        },
      );
      
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> confirmPayment(
    int violationId,
    String paymentIntentId,
  ) async {
    try {
      final response = await _dio.post(
        '/payments/confirm-payment/',
        data: {
          'violation_id': violationId,
          'payment_intent_id': paymentIntentId,
        },
      );
      
      return true;
    } catch (e) {
      rethrow;
    }
  }
}

