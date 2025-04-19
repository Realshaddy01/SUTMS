import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/violation.dart';
import '../models/violation_type.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ViolationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  // State
  List<Violation> _violations = [];
  List<Violation> _userViolations = [];
  Violation? _currentViolation;
  Violation? _selectedViolation;
  List<ViolationType> _violationTypes = [];
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _stats = {};
  final bool _useMockData = false;
  
  // Getters
  List<Violation> get violations => _violations;
  List<Violation> get userViolations => _userViolations;
  Violation? get currentViolation => _currentViolation;
  Violation? get selectedViolation => _selectedViolation;
  List<ViolationType> get violationTypes => _violationTypes;
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get stats => _stats;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;
  
  // Set selected violation
  void setSelectedViolation(Violation violation) {
    _selectedViolation = violation;
    notifyListeners();
  }
  
  // Fetch violations by status, period, or userType
  Future<void> fetchViolations({String? status, String? period, String? userType}) async {
    if (userType == 'vehicle_owner') {
      return loadUserViolations(status: status);
    } else {
      return loadViolations(status: status, period: period);
    }
  }
  
  // Get violation by ID
  Future<Violation?> getViolationById(int id) async {
    return getViolationDetails(id);
  }
  
  // Load all violations (for officer/admin)
  Future<void> loadViolations({String? status, String? period}) async {
    if (!_apiService.isAuthenticated) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (period != null) queryParams['period'] = period;
      
      final response = await _apiService.get(
        'violations/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _violations = data.map((violation) => Violation.fromJson(violation)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to load violations';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Load violations for current user
  Future<void> loadUserViolations({String? status}) async {
    if (!_apiService.isAuthenticated) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final queryParams = status != null ? {'status': status} : null;
      
      final response = await _apiService.get(
        'violations/user/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _userViolations = data.map((violation) => Violation.fromJson(violation)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to load user violations';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Load violations for a specific vehicle
  Future<List<Violation>> loadVehicleViolations(int vehicleId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('violations/vehicle/$vehicleId/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final violations = data.map((violation) => Violation.fromJson(violation)).toList();
        _isLoading = false;
        notifyListeners();
        return violations;
      } else {
        _isLoading = false;
        _error = 'Failed to load vehicle violations';
        notifyListeners();
        return [];
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return [];
    }
  }
  
  // Get violation details
  Future<Violation?> getViolationDetails(int violationId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('violations/$violationId/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final violation = Violation.fromJson(data);
        _currentViolation = violation;
        _isLoading = false;
        notifyListeners();
        return violation;
      } else {
        _isLoading = false;
        _error = 'Failed to get violation details';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return null;
    }
  }
  
  // Create a new violation
  Future<Violation?> createViolation(Map<String, dynamic> violationData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Extract image path from the data
      final String? imagePath = violationData.remove('image_path');
      
      // Create violation first
      final response = await _apiService.post('violations/', violationData);
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newViolation = Violation.fromJson(data);
        
        // If there's an image, upload it
        if (imagePath != null && imagePath.isNotEmpty) {
          await _uploadViolationEvidence(newViolation.id, File(imagePath));
        }
        
        // Fetch the updated violation with evidence URL
        final updatedViolation = await getViolationDetails(newViolation.id);
        
        _violations.add(updatedViolation ?? newViolation);
        _isLoading = false;
        notifyListeners();
        return updatedViolation ?? newViolation;
      } else {
        _isLoading = false;
        _error = 'Failed to create violation';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return null;
    }
  }
  
  // Upload evidence image for a violation
  Future<bool> _uploadViolationEvidence(int violationId, File imageFile) async {
    try {
      final response = await _apiService.uploadImage(
        'violations/$violationId/evidence/',
        imageFile,
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error uploading evidence: $e');
      return false;
    }
  }
  
  // Update violation status
  Future<bool> updateViolationStatus(int violationId, String status) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.patch(
        'violations/$violationId/status/',
        {'status': status},
      );
      
      if (response.statusCode == 200) {
        // Update in lists
        final int violationIndex = _violations.indexWhere((v) => v.id == violationId);
        if (violationIndex != -1) {
          _violations[violationIndex] = _violations[violationIndex].copyWith(status: status);
        }
        
        final int userViolationIndex = _userViolations.indexWhere((v) => v.id == violationId);
        if (userViolationIndex != -1) {
          _userViolations[userViolationIndex] = _userViolations[userViolationIndex].copyWith(status: status);
        }
        
        // Update current violation if it's the same
        if (_currentViolation?.id == violationId) {
          _currentViolation = _currentViolation!.copyWith(status: status);
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'Failed to update violation status';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Contest a violation
  Future<bool> contestViolation(int violationId, String reason) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.post(
        'violations/$violationId/contest/',
        {'reason': reason},
      );
      
      if (response.statusCode == 200) {
        // Fetch updated violation
        await getViolationDetails(violationId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'Failed to contest violation';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Submit appeal for a violation
  Future<bool> submitAppeal(int violationId, String reason, {File? evidenceFile}) async {
    setLoading(true);
    
    try {
      final token = await _storageService.getAuthToken();
      if (token == null) {
        setError("Not authenticated");
        return false;
      }
      
      Map<String, dynamic> result;
      if (evidenceFile != null) {
        result = await _apiService.submitViolationAppeal(
          token: token,
          violationId: violationId,
          reason: reason,
          evidenceFile: evidenceFile
        );
      } else {
        result = await _apiService.submitViolationAppeal(
          token: token,
          violationId: violationId,
          reason: reason
        );
      }
      
      // Update the violation in our local state
      _updateViolationStatus(violationId, 'disputed');
      
      // Add a notification for the appeal
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Appeal Submitted',
        message: 'Your appeal for violation #$violationId has been submitted successfully.',
        type: 'appeal_submitted',
        isRead: false,
        createdAt: DateTime.now(),
        violationId: violationId,
      );
      _notifications.insert(0, notification);
      
      // Return success
      return true;
    } catch (e) {
      setError(e.toString());
      
      // Return mock success for testing
      if (_useMockData) {
        // Pretend the appeal was submitted
        _updateViolationStatus(violationId, 'disputed');
        return true;
      }
      
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  // Fetch violation types with token
  Future<void> fetchViolationTypesWithToken(String? token) async {
    if (token == null) {
      return fetchViolationTypes();
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.getWithToken('violation-types/', token);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _violationTypes = data.map((type) => ViolationType.fromJson(type)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to load violation types';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Fetch violation types using default authentication
  Future<void> fetchViolationTypes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('violation-types/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _violationTypes = data.map((type) => ViolationType.fromJson(type)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to load violation types';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Load statistics
  Future<void> loadStats([String period = 'all']) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('violations/stats/', 
        queryParameters: {'period': period},
      );
      
      if (response.statusCode == 200) {
        _stats = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to load statistics';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Fetch notifications
  Future<void> fetchNotifications(String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.getWithToken('notifications/', token);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notifications = data.map((n) => NotificationModel.fromJson(n)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to fetch notifications';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId, String token) async {
    try {
      final response = await _apiService.patchWithToken(
        'notifications/$notificationId/read/',
        {},
        token
      );
      
      if (response.statusCode == 200) {
        // Update local notification
        final int index = _notifications.indexWhere((n) => n.id.toString() == notificationId);
        if (index != -1) {
          // Create a new notification with isRead set to true
          final updatedNotification = NotificationModel(
            id: _notifications[index].id,
            title: _notifications[index].title,
            message: _notifications[index].message,
            type: _notifications[index].type,
            isRead: true,
            createdAt: _notifications[index].createdAt,
            violationId: _notifications[index].violationId,
          );
          _notifications[index] = updatedNotification;
          notifyListeners();
        }
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }
  
  // Mark all notifications as read
  Future<bool> markAllNotificationsAsRead(String token) async {
    try {
      final response = await _apiService.postWithToken(
        'notifications/mark-all-read/',
        {},
        token
      );
      
      if (response.statusCode == 200) {
        // Update all local notifications
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
          violationId: n.violationId,
        )).toList();
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }
  
  // License plate detection
  Future<Map<String, dynamic>?> detectLicensePlate(File imageFile) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.uploadImage(
        'violations/detect-plate/',
        imageFile,
      );
      
      _isLoading = false;
      
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body);
        notifyListeners();
        return results;
      } else {
        _error = 'Failed to detect license plate';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return null;
    }
  }
  
  // Record a violation with token
  Future<bool> recordViolation(
    String token, {
    required int vehicleId,
    required int violationTypeId,
    required String location,
    String? description,
    required File evidenceImage,
    required int recordedById,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Create multipart request data
      final request = {
        'vehicle_id': vehicleId,
        'violation_type_id': violationTypeId,
        'location': location,
        'description': description ?? '',
        'recorded_by_id': recordedById,
      };
      
      // Upload evidence image and create violation
      final response = await _apiService.uploadFileWithToken(
        'violations/record/', 
        evidenceImage.path, 
        token,
        fields: request
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final violation = Violation.fromJson(data);
        
        // Add to violations list if it's an officer recording
        _violations.insert(0, violation);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'Failed to record violation';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Helper methods
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void setError(String? value) {
    _error = value;
    notifyListeners();
  }
  
  void _updateViolationStatus(int violationId, String status) async {
    await updateViolationStatus(violationId, status);
  }
}
