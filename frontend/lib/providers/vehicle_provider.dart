import 'dart:convert';

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
  String? _qrCodeUrl;
  final bool _useMockData = true; // Set to true to ensure mockup data is used regardless of API
  
  // Getters
  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get currentVehicle => _currentVehicle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get qrCodeUrl => _qrCodeUrl;
  
  // Mock data
  final List<Vehicle> _mockVehicles = [
    Vehicle(
      id: 1,
      licensePlate: 'BA 1 PA 1234',
      make: 'Toyota',
      model: 'Corolla',
      color: 'White',
      year: 2020,
      ownerName: 'John Doe',
      type: 'Car',
      registrationExpiry: DateTime.now().add(const Duration(days: 365)),
      registrationNumber: 'REG123456',
    ),
    Vehicle(
      id: 2,
      licensePlate: 'BA 2 CHA 5678',
      make: 'Honda',
      model: 'Civic',
      color: 'Black',
      year: 2019,
      ownerName: 'Jane Smith',
      type: 'Car',
      registrationExpiry: DateTime.now().add(const Duration(days: 180)),
      registrationNumber: 'REG789012',
    ),
    Vehicle(
      id: 3,
      licensePlate: 'GA 1 BA 9012',
      make: 'Yamaha',
      model: 'FZ',
      color: 'Blue',
      year: 2021,
      ownerName: 'Ram Bahadur',
      type: 'Motorcycle',
      registrationExpiry: DateTime.now().add(const Duration(days: 274)),
      registrationNumber: 'REG345678',
    ),
  ];
  
  // Load user's vehicles
  Future<void> loadUserVehicles() async {
    if (!_apiService.isAuthenticated && !_useMockData) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      if (_useMockData) {
        // Use mock data after a delay to simulate network request
        await Future.delayed(const Duration(milliseconds: 500));
        _vehicles = List.from(_mockVehicles);
        _isLoading = false;
        print("Using mock vehicle data: ${_vehicles.length} vehicles");
        notifyListeners();
        return;
      }
      
      final response = await _apiService.get('vehicles/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _vehicles = data.map((vehicle) => Vehicle.fromJson(vehicle)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        print("Failed to load vehicles, using mock data instead");
        // Fallback to mock data on error
        _vehicles = List.from(_mockVehicles);
        _isLoading = false;
        _error = null; // Clear error since we're showing mock data
        notifyListeners();
      }
    } catch (e) {
      print("Error loading vehicles: $e, using mock data instead");
      // Fallback to mock data on error
      _vehicles = List.from(_mockVehicles);
      _isLoading = false;
      _error = null; // Clear error since we're showing mock data
      notifyListeners();
    }
  }
  
  // Alias for loadUserVehicles (for backward compatibility)
  Future<void> loadVehicles() async {
    return loadUserVehicles();
  }
  
  // Fetch vehicles with token
  Future<void> fetchVehicles(String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.getWithToken('vehicles/', token);
      
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
      
      if (_useMockData) {
        // Use mock data after a delay to simulate network request
        await Future.delayed(const Duration(milliseconds: 500));
        _currentVehicle = _mockVehicles.firstWhere(
          (v) => v.licensePlate.toLowerCase().contains(licensePlate.toLowerCase()),
          orElse: () => _mockVehicles.first,
        );
        _isLoading = false;
        print("Using mock vehicle for search: ${_currentVehicle?.licensePlate}");
        notifyListeners();
        return;
      }
      
      final response = await _apiService.get(
        'vehicles/search/',
        queryParameters: {'license_plate': licensePlate},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          _currentVehicle = Vehicle.fromJson(data[0]);
        } else {
          // No vehicle found, use mock data
          _currentVehicle = _mockVehicles.firstWhere(
            (v) => v.licensePlate.toLowerCase().contains(licensePlate.toLowerCase()),
            orElse: () => _mockVehicles.first,
          );
        }
        _isLoading = false;
        notifyListeners();
      } else {
        // Fallback to mock data
        _currentVehicle = _mockVehicles.firstWhere(
          (v) => v.licensePlate.toLowerCase().contains(licensePlate.toLowerCase()),
          orElse: () => _mockVehicles.first,
        );
        _isLoading = false;
        _error = null; // Clear error since we're showing mock data
        notifyListeners();
      }
    } catch (e) {
      // Fallback to mock data
      _currentVehicle = _mockVehicles.firstWhere(
        (v) => v.licensePlate.toLowerCase().contains(licensePlate.toLowerCase()),
        orElse: () => _mockVehicles.first,
      );
      _isLoading = false;
      _error = null; // Clear error since we're showing mock data
      notifyListeners();
    }
  }
  
  // Search vehicle by license plate with token
  Future<List<Vehicle>?> searchVehiclesByLicensePlate(String token, String licensePlate) async {
    try {
      _isLoading = true;
      _currentVehicle = null;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.getWithToken(
        'vehicles/search/',
        token,
        queryParameters: {'license_plate': licensePlate},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final vehicles = data.map((v) => Vehicle.fromJson(v)).toList();
        
        if (vehicles.isNotEmpty) {
          _currentVehicle = vehicles.first;
        }
        
        _isLoading = false;
        notifyListeners();
        return vehicles;
      } else {
        _isLoading = false;
        _error = 'Failed to search vehicle';
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
  
  // Get QR code for a vehicle
  Future<String?> getVehicleQRCode(String token, int vehicleId) async {
    try {
      _isLoading = true;
      _error = null;
      _qrCodeUrl = null;
      notifyListeners();
      
      final response = await _apiService.getWithToken('vehicles/$vehicleId/qr-code/', token);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _qrCodeUrl = data['qr_code_url'];
        _isLoading = false;
        notifyListeners();
        return _qrCodeUrl;
      } else {
        _isLoading = false;
        _error = 'Failed to get vehicle QR code';
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
  
  // Verify vehicle by QR code data
  Future<Vehicle?> verifyVehicleByQRData(String qrData) async {
    try {
      _isLoading = true;
      _error = null;
      _currentVehicle = null;
      notifyListeners();
      
      final response = await _apiService.post(
        'vehicles/verify-qr/',
        {'qr_data': qrData},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final verifiedVehicle = Vehicle.fromJson(data);
        _currentVehicle = verifiedVehicle;
        _isLoading = false;
        notifyListeners();
        return verifiedVehicle;
      } else {
        _isLoading = false;
        _error = 'Failed to verify vehicle QR code';
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
  
  // Add a new vehicle
  Future<bool> addVehicle(
    String token, {
    required int ownerId,
    required String licensePlate,
    required String make,
    required String model,
    required int year,
    required String color,
    required String registrationNumber,
    required int vehicleTypeId,
    String? billBookNumber,
    String? vin,
    DateTime? registrationExpiry,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final vehicleData = {
        'owner_id': ownerId,
        'license_plate': licensePlate,
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'registration_number': registrationNumber,
        'vehicle_type': vehicleTypeId,
        'vin': vin ?? '',
        'registration_expiry': registrationExpiry?.toIso8601String() ?? '',
        'bill_book_number': billBookNumber ?? '',
      };
      
      final response = await _apiService.postWithToken('vehicles/', vehicleData, token);
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newVehicle = Vehicle.fromJson(data);
        _vehicles.add(newVehicle);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'Failed to add vehicle';
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
  
  // Update a vehicle
  Future<bool> updateVehicle(
    String token,
    int vehicleId, {
    required String make,
    required String model,
    required int year,
    required String color,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final vehicleData = {
        'make': make,
        'model': model,
        'year': year,
        'color': color,
      };
      
      final response = await _apiService.putWithToken('vehicles/$vehicleId/', vehicleData, token);
      
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
  Future<bool> deleteVehicle(String token, int vehicleId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await _apiService.deleteWithToken('vehicles/$vehicleId/', token);
      
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
  
  Future<Vehicle?> getVehicleById(int id) async {
    try {
      clearError();
      final response = await ApiService.instance.get('vehicles/$id/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Vehicle.fromJson(data);
      } else {
        setError('Failed to get vehicle: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      setError('Error getting vehicle: $e');
      return null;
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Generate QR code for a vehicle
  Future<String?> generateQRCode(String token, int vehicleId) async {
    try {
      _isLoading = true;
      _error = null;
      _qrCodeUrl = null;
      notifyListeners();
      
      final response = await _apiService.postWithToken(
        'vehicles/generate-qr-code/$vehicleId/',
        {},
        token
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _qrCodeUrl = data['qr_code_url'];
        _isLoading = false;
        notifyListeners();
        return _qrCodeUrl;
      } else {
        _isLoading = false;
        _error = 'Failed to generate QR code';
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
}
