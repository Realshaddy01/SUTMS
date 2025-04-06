import 'package:flutter/foundation.dart';
import 'package:sutms_flutter/models/analytics_data.dart';
import 'package:sutms_flutter/services/api_service.dart';

class AnalyticsProvider with ChangeNotifier {
  final ApiService _apiService;
  
  bool _loading = false;
  String _selectedPeriod = 'month';
  AnalyticsData? _analyticsData;
  String? _error;
  
  AnalyticsProvider({required ApiService apiService}) : _apiService = apiService;
  
  // Getters
  bool get isLoading => _loading;
  String get selectedPeriod => _selectedPeriod;
  AnalyticsData? get analyticsData => _analyticsData;
  String? get error => _error;
  
  // Methods
  void setPeriod(String period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      fetchAnalyticsData();
    }
  }
  
  Future<void> fetchAnalyticsData() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();
      
      final data = await _apiService.getAnalyticsData(_selectedPeriod);
      _analyticsData = data;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = 'Failed to load analytics data: ${e.toString()}';
      notifyListeners();
    }
  }
  
  void refresh() {
    fetchAnalyticsData();
  }
}
