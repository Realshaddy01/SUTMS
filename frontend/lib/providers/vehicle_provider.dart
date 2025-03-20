import 'package:flutter/material.dart';
import 'package:sutms/models/vehicle_model.dart';
import 'package:sutms/services/api_service.dart';

class VehicleProvider with ChangeNotifier {
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;
  final ApiService _apiService = ApiService();

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final vehiclesData = await _apiService.getVehicles();
      _vehicles = vehiclesData.map((data) => Vehicle.fromJson(data)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Vehicle> fetchVehicle(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final vehicleData = await _apiService.getVehicle(id);
      final vehicle = Vehicle.fromJson(vehicleData);
      
      // Update vehicle in list if it exists
      final index = _vehicles.indexWhere((v) => v.id == id);
      if (index >= 0) {
        _vehicles[index] = vehicle;
      } else {
        _vehicles.add(vehicle);
      }
      
      _isLoading = false;
      notifyListeners();
      return vehicle;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Vehicle> addVehicle(Map<String, dynamic> vehicleData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final newVehicleData = await _apiService.addVehicle(vehicleData);
      final newVehicle = Vehicle.fromJson(newVehicleData);
      _vehicles.add(newVehicle);
      _isLoading = false;
      notifyListeners();
      return newVehicle;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> vehicleData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final updatedVehicleData = await _apiService.updateVehicle(id, vehicleData);
      final updatedVehicle = Vehicle.fromJson(updatedVehicleData);
      
      final index = _vehicles.indexWhere((v) => v.id == id);
      if (index >= 0) {
        _vehicles[index] = updatedVehicle;
      }
      
      _isLoading = false;
      notifyListeners();
      return updatedVehicle;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteVehicle(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _apiService.deleteVehicle(id);
      _vehicles.removeWhere((v) => v.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

