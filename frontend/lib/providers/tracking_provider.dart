import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
// import 'package:location/location.dart'; // Temporarily commented out
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/officer_location.dart';
import '../models/traffic_signal.dart';
import '../models/traffic_incident.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class TrackingProvider with ChangeNotifier {
  // final Location _location = Location(); // Temporarily commented out
  GoogleMapController? _mapController;
  
  // User's current location
  // LocationData? _currentLocation; // Temporarily commented out
  dynamic _currentLocation; // Temporary replacement
  bool _locationPermissionGranted = false;
  // StreamSubscription<LocationData>? _locationSubscription; // Temporarily commented out
  StreamSubscription? _locationSubscription; // Temporary replacement
  
  // Tracking data
  List<OfficerLocation> _activeOfficers = [];
  List<TrafficSignal> _trafficSignals = [];
  List<TrafficIncident> _activeIncidents = [];
  
  // Display flags for map layers
  bool _showOfficers = true;
  bool _showTrafficSignals = true;
  bool _showIncidents = true;
  
  // Map markers
  final Set<Marker> _markers = {};
  
  // Filter settings
  double _nearbyRadius = Constants.nearbyRadius; // km
  
  // Timers for data refreshing
  Timer? _dataRefreshTimer;
  
  // Getters
  dynamic get currentLocation => _currentLocation;
  bool get locationPermissionGranted => _locationPermissionGranted;
  GoogleMapController? get mapController => _mapController;
  List<OfficerLocation> get activeOfficers => _activeOfficers;
  List<TrafficSignal> get trafficSignals => _trafficSignals;
  List<TrafficIncident> get activeIncidents => _activeIncidents;
  bool get showOfficers => _showOfficers;
  bool get showTrafficSignals => _showTrafficSignals;
  bool get showIncidents => _showIncidents;
  Set<Marker> get markers => _markers;
  double get nearbyRadius => _nearbyRadius;
  
  // Initial camera position (defaults to Kathmandu)
  final LatLng _kathmandu = const LatLng(27.7172, 85.3240);
  LatLng get initialCameraPosition => _currentLocation != null
      ? LatLng(_currentLocation['latitude'], _currentLocation['longitude'])
      : _kathmandu;
  
  // Initialize tracking
  Future<void> init() async {
    // Request location permission
    await _checkLocationPermission();
    
    if (_locationPermissionGranted) {
      // Get current location
      await _getCurrentLocation();
      
      // Start location updates
      _startLocationUpdates();
    }
    
    // Start data refresh timer
    _startDataRefreshTimer();
    
    // Initial data fetch
    await fetchAllTrackingData();
  }
  
  // Check location permission
  Future<void> _checkLocationPermission() async {
    /*
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }
    
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    */
    
    _locationPermissionGranted = false; // Default to false while commented
    notifyListeners();
  }
  
  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // _currentLocation = await _location.getLocation();
      // Temporary hard-coded location (Kathmandu)
      _currentLocation = {"latitude": 27.7172, "longitude": 85.3240};
      notifyListeners();
    } catch (e) {
      print('Error getting location: $e');
    }
  }
  
  // Start location updates
  void _startLocationUpdates() {
    try {
      /*
      _locationSubscription = _location.onLocationChanged.listen((LocationData locationData) {
        _currentLocation = locationData;
        notifyListeners();
        
        if (ApiService.instance.isAuthenticated && 
            ApiService.instance.userRole == Constants.roleOfficer) {
          _sendOfficerLocation();
        }
      });
      */
    } catch (e) {
      print('Error starting location updates: $e');
    }
  }
  
  // Send officer location to server
  Future<void> _sendOfficerLocation() async {
    if (_currentLocation == null) return;
    
    try {
      await ApiService.instance.post(
        'officer-locations/',
        {
          'latitude': _currentLocation['latitude'],
          'longitude': _currentLocation['longitude'],
          'accuracy': 0, // Assuming no accuracy data
          'speed': 0, // Assuming no speed data
          'heading': 0, // Assuming no heading data
          'is_active': true,
          'battery_level': 100, // TODO: Implement battery level detection
        },
      );
    } catch (e) {
      print('Error sending officer location: $e');
    }
  }
  
  // Set map controller
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }
  
  // Animate to current location
  void animateToCurrentLocation() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentLocation['latitude'], _currentLocation['longitude']),
            zoom: Constants.defaultMapZoom,
          ),
        ),
      );
    }
  }
  
  // Start data refresh timer
  void _startDataRefreshTimer() {
    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => fetchAllTrackingData(),
    );
  }
  
  // Fetch all tracking data
  Future<void> fetchAllTrackingData() async {
    if (!ApiService.instance.isAuthenticated) return;
    
    try {
      await Future.wait([
        fetchActiveOfficers(),
        fetchTrafficSignals(),
        fetchActiveIncidents(),
      ]);
      
      _updateMarkers();
    } catch (e) {
      print('Error fetching tracking data: $e');
    }
  }
  
  // Fetch active officers
  Future<void> fetchActiveOfficers() async {
    try {
      final response = await ApiService.instance.get('officer-locations/active_officers/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _activeOfficers = data.map((json) => OfficerLocation.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching active officers: $e');
    }
  }
  
  // Fetch traffic signals
  Future<void> fetchTrafficSignals() async {
    try {
      final response = await ApiService.instance.get('traffic-signals/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _trafficSignals = data.map((json) => TrafficSignal.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching traffic signals: $e');
    }
  }
  
  // Fetch active incidents
  Future<void> fetchActiveIncidents() async {
    try {
      final response = await ApiService.instance.get(
        'traffic-incidents/',
        queryParameters: {'active': 'true'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _activeIncidents = data.map((json) => TrafficIncident.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching active incidents: $e');
    }
  }
  
  // Fetch nearby traffic signals
  Future<List<TrafficSignal>> fetchNearbyTrafficSignals() async {
    if (_currentLocation == null) return [];
    
    try {
      final response = await ApiService.instance.get(
        'traffic-signals/nearby/',
        queryParameters: {
          'lat': _currentLocation['latitude'].toString(),
          'lng': _currentLocation['longitude'].toString(),
          'radius': _nearbyRadius.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => TrafficSignal.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching nearby traffic signals: $e');
    }
    
    return [];
  }
  
  // Fetch nearby incidents
  Future<List<TrafficIncident>> fetchNearbyIncidents() async {
    if (_currentLocation == null) return [];
    
    try {
      final response = await ApiService.instance.get(
        'traffic-incidents/nearby/',
        queryParameters: {
          'lat': _currentLocation['latitude'].toString(),
          'lng': _currentLocation['longitude'].toString(),
          'radius': _nearbyRadius.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => TrafficIncident.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching nearby incidents: $e');
    }
    
    return [];
  }
  
  // Update signal phase
  Future<bool> updateSignalPhase(int signalId, String phase, {int? timeRemaining}) async {
    try {
      final response = await ApiService.instance.patch(
        'traffic-signals/$signalId/update_phase/',
        {
          'phase': phase,
          if (timeRemaining != null) 'time_remaining': timeRemaining,
        },
      );
      
      if (response.statusCode == 200) {
        await fetchTrafficSignals();
        return true;
      }
    } catch (e) {
      print('Error updating signal phase: $e');
    }
    
    return false;
  }
  
  // Report a traffic incident
  Future<bool> reportTrafficIncident(Map<String, dynamic> incidentData) async {
    try {
      final response = await ApiService.instance.post(
        'traffic-incidents/',
        incidentData,
      );
      
      if (response.statusCode == 201) {
        await fetchActiveIncidents();
        return true;
      }
    } catch (e) {
      print('Error reporting traffic incident: $e');
    }
    
    return false;
  }
  
  // Verify a traffic incident
  Future<bool> verifyTrafficIncident(int incidentId) async {
    try {
      final response = await ApiService.instance.post(
        'traffic-incidents/$incidentId/verify/',
        {},
      );
      
      if (response.statusCode == 200) {
        await fetchActiveIncidents();
        return true;
      }
    } catch (e) {
      print('Error verifying traffic incident: $e');
    }
    
    return false;
  }
  
  // Resolve a traffic incident
  Future<bool> resolveTrafficIncident(int incidentId) async {
    try {
      final response = await ApiService.instance.post(
        'traffic-incidents/$incidentId/resolve/',
        {},
      );
      
      if (response.statusCode == 200) {
        await fetchActiveIncidents();
        return true;
      }
    } catch (e) {
      print('Error resolving traffic incident: $e');
    }
    
    return false;
  }
  
  // Toggle display of officers on map
  void toggleOfficersDisplay() {
    _showOfficers = !_showOfficers;
    _updateMarkers();
    notifyListeners();
  }
  
  // Toggle display of traffic signals on map
  void toggleTrafficSignalsDisplay() {
    _showTrafficSignals = !_showTrafficSignals;
    _updateMarkers();
    notifyListeners();
  }
  
  // Toggle display of incidents on map
  void toggleIncidentsDisplay() {
    _showIncidents = !_showIncidents;
    _updateMarkers();
    notifyListeners();
  }
  
  // Set nearby radius
  void setNearbyRadius(double radius) {
    _nearbyRadius = radius;
    notifyListeners();
  }
  
  // Update map markers
  void _updateMarkers() {
    _markers.clear();
    
    // Add user location marker
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentLocation['latitude'], _currentLocation['longitude']),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    
    // Add officer markers
    if (_showOfficers) {
      for (final officer in _activeOfficers) {
        _markers.add(
          Marker(
            markerId: MarkerId('officer_${officer.id}'),
            position: LatLng(officer.latitude, officer.longitude),
            infoWindow: InfoWindow(
              title: 'Officer: ${officer.officerName}',
              snippet: 'Active',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    }
    
    // Add traffic signal markers
    if (_showTrafficSignals) {
      for (final signal in _trafficSignals) {
        // Choose color based on signal phase
        double hue;
        switch (signal.currentPhase) {
          case 'red':
            hue = BitmapDescriptor.hueRed;
            break;
          case 'yellow':
            hue = BitmapDescriptor.hueYellow;
            break;
          case 'green':
            hue = BitmapDescriptor.hueGreen;
            break;
          default:
            hue = BitmapDescriptor.hueViolet;
        }
        
        _markers.add(
          Marker(
            markerId: MarkerId('signal_${signal.id}'),
            position: LatLng(signal.latitude, signal.longitude),
            infoWindow: InfoWindow(
              title: signal.name,
              snippet: 'Status: ${signal.status}, Phase: ${signal.currentPhase}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          ),
        );
      }
    }
    
    // Add incident markers
    if (_showIncidents) {
      for (final incident in _activeIncidents) {
        // Choose color based on incident severity
        double hue;
        switch (incident.severity) {
          case 1: // Low
            hue = BitmapDescriptor.hueYellow;
            break;
          case 2: // Medium
            hue = BitmapDescriptor.hueOrange;
            break;
          case 3: // High
            hue = BitmapDescriptor.hueRed;
            break;
          case 4: // Critical
            hue = BitmapDescriptor.hueRose;
            break;
          default:
            hue = BitmapDescriptor.hueRed;
        }
        
        _markers.add(
          Marker(
            markerId: MarkerId('incident_${incident.id}'),
            position: LatLng(incident.latitude, incident.longitude),
            infoWindow: InfoWindow(
              title: incident.incidentTypeDisplay,
              snippet: 'Severity: ${incident.severityDisplay}\n${incident.description}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          ),
        );
      }
    }
    
    notifyListeners();
  }
  
  // Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double radiusOfEarth = 6371; // Earth's radius in kilometers
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radiusOfEarth * c;
  }  
  // Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }
  
  // Clean up resources
  @override
  void dispose() {
    // _locationSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
