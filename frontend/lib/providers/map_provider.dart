import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_heatmap_map/flutter_heatmap_map.dart';

import '../services/api_service.dart';
import '../utils/constants.dart';

class MapProvider with ChangeNotifier {
  // Violation hotspot data
  List<HeatmapPoint> _hotspotPoints = [];
  bool _showHotspots = false;
  String _hotspotPeriod = Constants.periodMonth;
  String? _hotspotViolationType;
  
  // Map controller for heatmap
  GoogleMapController? _mapController;
  
  // Getters
  List<HeatmapPoint> get hotspotPoints => _hotspotPoints;
  bool get showHotspots => _showHotspots;
  String get hotspotPeriod => _hotspotPeriod;
  String? get hotspotViolationType => _hotspotViolationType;
  
  // Initialize the provider
  Future<void> init() async {
    await fetchHotspots();
  }
  
  // Set map controller
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }
  
  // Toggle hotspots display
  void toggleHotspots() {
    _showHotspots = !_showHotspots;
    notifyListeners();
  }
  
  // Set hotspot period
  void setHotspotPeriod(String period) {
    _hotspotPeriod = period;
    fetchHotspots();
    notifyListeners();
  }
  
  // Set hotspot violation type
  void setHotspotViolationType(String? type) {
    _hotspotViolationType = type;
    fetchHotspots();
    notifyListeners();
  }
  
  // Fetch violation hotspots from API
  Future<void> fetchHotspots() async {
    if (!ApiService.instance.isAuthenticated) return;
    
    try {
      // Prepare query parameters
      final queryParams = {
        'period': _hotspotPeriod,
        'limit': '100',
      };
      
      if (_hotspotViolationType != null) {
        queryParams['type'] = _hotspotViolationType!;
      }
      
      final response = await ApiService.instance.get(
        'analytics/hotspots/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hotspots = data['hotspots'] as List;
        
        _hotspotPoints = hotspots.map((hotspot) {
          return HeatmapPoint(
            latitude: hotspot['lat'],
            longitude: hotspot['lng'],
            intensity: hotspot['weight'].toDouble(),
          );
        }).toList();
        
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching hotspots: $e');
    }
  }
  
  // Get violation statistics
  Future<Map<String, dynamic>> fetchViolationStats({String? period}) async {
    if (!ApiService.instance.isAuthenticated) return {};
    
    try {
      final queryParams = period != null ? {'period': period} : null;
      
      final response = await ApiService.instance.get(
        'analytics/violations_by_type/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return {
          'violations_by_type': data,
        };
      }
    } catch (e) {
      print('Error fetching violation stats: $e');
    }
    
    return {};
  }
  
  // Get violation trends over time
  Future<Map<String, dynamic>> fetchViolationTrends({
    String period = 'month',
    String? violationType,
  }) async {
    if (!ApiService.instance.isAuthenticated) return {};
    
    try {
      final queryParams = {
        'period': period,
      };
      
      if (violationType != null) {
        queryParams['type'] = violationType;
      }
      
      final response = await ApiService.instance.get(
        'analytics/violations_over_time/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return {
          'violations_over_time': data,
        };
      }
    } catch (e) {
      print('Error fetching violation trends: $e');
    }
    
    return {};
  }
  
  // Get hourly distribution of violations
  Future<Map<String, dynamic>> fetchHourlyDistribution({
    String? violationType,
  }) async {
    if (!ApiService.instance.isAuthenticated) return {};
    
    try {
      final queryParams = violationType != null ? {'type': violationType} : null;
      
      final response = await ApiService.instance.get(
        'analytics/hourly_distribution/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return {
          'hourly_distribution': data,
        };
      }
    } catch (e) {
      print('Error fetching hourly distribution: $e');
    }
    
    return {};
  }
  
  // Get summary statistics
  Future<Map<String, dynamic>> fetchSummaryStats() async {
    if (!ApiService.instance.isAuthenticated) return {};
    
    try {
      final response = await ApiService.instance.get('analytics/summary/');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching summary stats: $e');
    }
    
    return {};
  }
  
  // Get officer performance statistics
  Future<Map<String, dynamic>> fetchOfficerPerformance({
    String period = 'month',
  }) async {
    if (!ApiService.instance.isAuthenticated ||
        ApiService.instance.userRole != Constants.roleAdmin) {
      return {};
    }
    
    try {
      final queryParams = {'period': period};
      
      final response = await ApiService.instance.get(
        'analytics/officer_performance/',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return {
          'officer_performance': data,
        };
      }
    } catch (e) {
      print('Error fetching officer performance: $e');
    }
    
    return {};
  }
  
  // Clean up resources
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
