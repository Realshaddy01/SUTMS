import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:location/location.dart' as loc; // Temporarily commented out
import 'package:provider/provider.dart';

import '../providers/violation_provider.dart';
import '../providers/violation_type_provider.dart';
import '../utils/constants.dart';
import '../widgets/loading_overlay.dart';

class ViolationFormScreen extends StatefulWidget {
  final String licensePlate;
  final String? imagePath;
  final int? vehicleId;
  
  const ViolationFormScreen({
    Key? key,
    required this.licensePlate,
    this.imagePath,
    this.vehicleId,
  }) : super(key: key);

  @override
  _ViolationFormScreenState createState() => _ViolationFormScreenState();
}

class _ViolationFormScreenState extends State<ViolationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedViolationType;
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  // late loc.LocationData _locationData; // Temporarily commented out
  // Instead, use a Map to store location data
  late Map<String, dynamic> _locationData = {
    'latitude': 27.7172,
    'longitude': 85.3240
  };
  bool _isLocationLoading = true;
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    
    // Load violation types
    Future.microtask(() {
      Provider.of<ViolationTypeProvider>(context, listen: false).loadViolationTypes();
    });
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });
    
    // Simulated location data since location package is temporarily disabled
    /*
    final location = loc.Location();
    
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;
    
    // Check if location service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        setState(() {
          _isLocationLoading = false;
          _locationController.text = 'Location service is disabled';
        });
        return;
      }
    }
    
    // Check if permission is granted
    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        setState(() {
          _isLocationLoading = false;
          _locationController.text = 'Location permission is denied';
        });
        return;
      }
    }
    
    try {
      // Get location
      _locationData = await location.getLocation();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLocationLoading = false;
        _locationController.text = 'Failed to get location';
      });
      return;
    }
    */
    
    // Use dummy location data instead
    _locationData = {
      'latitude': 27.7172,
      'longitude': 85.3240
    };
    
    setState(() {
      _isLocationLoading = false;
      _locationController.text = 'Lat: ${_locationData['latitude']}, Lng: ${_locationData['longitude']}';
    });
  }
  
  Future<void> _submitViolation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedViolationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a violation type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      final violationTypeProvider = Provider.of<ViolationTypeProvider>(context, listen: false);
      
      final violationType = violationTypeProvider.violationTypes
          .firstWhere((type) => type.id.toString() == _selectedViolationType);
      
      final result = await violationProvider.createViolation({
        'license_plate': widget.licensePlate,
        'vehicle_id': widget.vehicleId,
        'violation_type': _selectedViolationType,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'latitude': _isLocationLoading ? null : _locationData['latitude'],
        'longitude': _isLocationLoading ? null : _locationData['longitude'],
        'fine_amount': violationType.baseFine,
        'image_path': widget.imagePath,
      });
      
      setState(() {
        _isSubmitting = false;
      });
      
      if (result != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Violation reported successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to previous screen after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(violationProvider.error ?? 'Failed to report violation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reporting violation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Violation'),
        elevation: Constants.appBarElevation,
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting || _isLocationLoading,
        loadingText: _isSubmitting ? 'Submitting violation...' : 'Getting location...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Constants.defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // License plate and image preview
                Card(
                  elevation: Constants.cardElevation,
                  child: Padding(
                    padding: const EdgeInsets.all(Constants.defaultPadding),
                    child: Row(
                      children: [
                        if (widget.imagePath != null)
                          Container(
                            width: 120,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(widget.imagePath!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(width: Constants.defaultPadding),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'License Plate',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                widget.licensePlate,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: Constants.defaultPadding),
                
                // Violation type dropdown
                _buildViolationTypeDropdown(),
                
                const SizedBox(height: Constants.defaultPadding),
                
                // Description field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: Constants.defaultPadding),
                
                // Location field
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: const OutlineInputBorder(),
                    suffixIcon: _isLocationLoading
                        ? Container(
                            width: 20,
                            height: 20,
                            padding: const EdgeInsets.all(8),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _getCurrentLocation,
                          ),
                  ),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Location is required';
                    }
                    if (value.contains('disabled') || value.contains('denied') || value.contains('Failed')) {
                      return 'Valid location is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: Constants.largePadding),
                
                // Submit button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitViolation,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Submit Violation Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildViolationTypeDropdown() {
    final violationTypeProvider = Provider.of<ViolationTypeProvider>(context);
    
    if (violationTypeProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (violationTypeProvider.error != null) {
      return Center(
        child: Text(
          'Error loading violation types: ${violationTypeProvider.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    
    final violationTypes = violationTypeProvider.violationTypes;
    
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Violation Type',
        border: OutlineInputBorder(),
      ),
      value: _selectedViolationType,
      items: violationTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type.id.toString(),
          child: Text('${type.name} (Npr ${type.baseFine})'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedViolationType = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a violation type';
        }
        return null;
      },
    );
  }
}
