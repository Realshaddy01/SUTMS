import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/violation_type.dart';
import '../services/api_service.dart';

class ViolationTypeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // State
  List<ViolationType> _violationTypes = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<ViolationType> get violationTypes => _violationTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Load violation types
  Future<void> loadViolationTypes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('violations/types/');
      
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
  
  // Get violation type by ID
  ViolationType? getViolationTypeById(int id) {
    try {
      return _violationTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
