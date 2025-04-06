import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/violation.dart';
import '../services/api_service.dart';

class ViolationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // State
  List<Violation> _violations = [];
  List<Violation> _userViolations = [];
  Violation? _currentViolation;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<Violation> get violations => _violations;
  List<Violation> get userViolations => _userViolations;
  Violation? get currentViolation => _currentViolation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
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
  
  // Get violation statistics
  Future<Map<String, dynamic>> getViolationStats({String? period}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final queryParams = period != null ? {'period': period} : null;
      
      final response = await _apiService.get(
        'statistics/violations/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return data;
      } else {
        _isLoading = false;
        _error = 'Failed to get violation statistics';
        notifyListeners();
        return {};
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
      return {};
    }
  }
  
  // Get hotspot locations
  Future<List<Map<String, dynamic>>> getViolationHotspots() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('statistics/hotspots/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return data.cast<Map<String, dynamic>>();
      } else {
        _isLoading = false;
        _error = 'Failed to get violation hotspots';
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
  
  // Set current violation
  void setCurrentViolation(Violation? violation) {
    _currentViolation = violation;
    notifyListeners();
  }
  
  // Clear current violation
  void clearCurrentViolation() {
    _currentViolation = null;
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
