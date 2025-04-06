import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';

class VehicleProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // State
  List<Vehicle> _vehicles = [];
  Vehicle? _currentVehicle;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get currentVehicle => _currentVehicle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Load user's vehicles
  Future<void> loadUserVehicles() async {
    if (!_apiService.isAuthenticated) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get('vehicles/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _vehicles = data.map((vehicle) => Vehicle.fromJson(vehicle)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to load vehicles';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Search vehicle by license plate
  Future<void> searchVehicleByLicensePlate(String licensePlate) async {
    try {
      _isLoading = true;
      _currentVehicle = null;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.get(
        'vehicles/search/',
        queryParameters: {'license_plate': licensePlate},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          _currentVehicle = Vehicle.fromJson(data[0]);
        } else {
          // No vehicle found with this license plate
          _currentVehicle = null;
        }
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _error = 'Failed to search vehicle';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error: $e';
      notifyListeners();
    }
  }
  
  // Add a new vehicle
  Future<Vehicle?> addVehicle(Map<String, dynamic> vehicleData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.post('vehicles/', vehicleData);
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newVehicle = Vehicle.fromJson(data);
        _vehicles.add(newVehicle);
        _isLoading = false;
        notifyListeners();
        return newVehicle;
      } else {
        _isLoading = false;
        _error = 'Failed to add vehicle';
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
  
  // Update a vehicle
  Future<bool> updateVehicle(int vehicleId, Map<String, dynamic> vehicleData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.put('vehicles/$vehicleId/', vehicleData);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedVehicle = Vehicle.fromJson(data);
        
        // Update in the list
        final index = _vehicles.indexWhere((v) => v.id == vehicleId);
        if (index != -1) {
          _vehicles[index] = updatedVehicle;
        }
        
        // Update current vehicle if it's the same
        if (_currentVehicle?.id == vehicleId) {
          _currentVehicle = updatedVehicle;
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'Failed to update vehicle';
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
  
  // Delete a vehicle
  Future<bool> deleteVehicle(int vehicleId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.delete('vehicles/$vehicleId/');
      
      if (response.statusCode == 204) {
        // Remove from the list
        _vehicles.removeWhere((v) => v.id == vehicleId);
        
        // Reset current vehicle if it's the same
        if (_currentVehicle?.id == vehicleId) {
          _currentVehicle = null;
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'Failed to delete vehicle';
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
  
  // Set current vehicle
  void setCurrentVehicle(Vehicle? vehicle) {
    _currentVehicle = vehicle;
    notifyListeners();
  }
  
  // Clear current vehicle
  void clearCurrentVehicle() {
    _currentVehicle = null;
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
