import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import '../widgets/loading_overlay.dart';

class ViolationReportScreen extends StatefulWidget {
  const ViolationReportScreen({super.key});

  @override
  _ViolationReportScreenState createState() => _ViolationReportScreenState();
}

class _ViolationReportScreenState extends State<ViolationReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  int? _vehicleId;
  String? _licensePlate;
  int? _selectedViolationTypeId;
  
  List<Map<String, dynamic>> _violationTypes = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  File? _evidenceImage;
  File? _licensePlateImage;
  
  double? _latitude;
  double? _longitude;
  
  final ApiService _apiService = ApiService();
  
  @override
  void initState() {
    super.initState();
    _loadViolationTypes();
    _getCurrentLocation();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get arguments from route
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _vehicleId = args['vehicle_id'];
      _licensePlate = args['license_plate'];
      
      // If there's an existing image, set it
      if (args.containsKey('plate_image')) {
        _licensePlateImage = args['plate_image'];
      }
    }
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadViolationTypes() async {
    try {
      final violationTypes = await _apiService.getViolationTypes();
      setState(() {
        _violationTypes = violationTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showSnackBar(context, 'Error loading violation types: $e');
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showSnackBar(context, 'Location permission denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        showSnackBar(context, 'Location permissions are permanently denied');
        return;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '${place.street}, ${place.subLocality}, ${place.locality}';
        
        setState(() {
          _locationController.text = address;
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }
  
  Future<void> _pickImage(ImageSource source, bool isEvidence) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile != null) {
        setState(() {
          if (isEvidence) {
            _evidenceImage = File(pickedFile.path);
          } else {
            _licensePlateImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      showSnackBar(context, 'Error picking image: $e');
    }
  }
  
  Future<void> _submitViolationReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedViolationTypeId == null) {
      showSnackBar(context, 'Please select a violation type');
      return;
    }
    
    if (_evidenceImage == null) {
      showSnackBar(context, 'Please provide evidence image');
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final response = await _apiService.reportViolation(
        vehicleId: _vehicleId!,
        violationTypeId: _selectedViolationTypeId!,
        location: _locationController.text,
        description: _descriptionController.text,
        latitude: _latitude,
        longitude: _longitude,
        evidenceImage: _evidenceImage,
        licensePlateImage: _licensePlateImage,
      );
      
      setState(() {
        _isSubmitting = false;
      });
      
      if (response['success'] == true) {
        // Show success message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Violation Reported'),
            content: const Text('Violation has been reported successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Return to previous screen with success
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showSnackBar(context, 'Error: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      showSnackBar(context, 'Error reporting violation: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Violation'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading || _isSubmitting,
        loadingText: _isSubmitting ? 'Submitting report...' : 'Loading...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle info section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Information',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'License Plate: $_licensePlate',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Violation type dropdown
                Text(
                  'Violation Type',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: const Text('Select violation type'),
                      value: _selectedViolationTypeId,
                      items: _violationTypes.map((type) {
                        return DropdownMenuItem<int>(
                          value: type['id'],
                          child: Text(type['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedViolationTypeId = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location field
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: _getCurrentLocation,
                      tooltip: 'Get current location',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Description field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Evidence image section
                Text(
                  'Evidence Image',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildImageSection(
                  image: _evidenceImage,
                  onTapCamera: () => _pickImage(ImageSource.camera, true),
                  onTapGallery: () => _pickImage(ImageSource.gallery, true),
                ),
                const SizedBox(height: 16),
                
                // License plate image section
                Text(
                  'License Plate Image (Optional)',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildImageSection(
                  image: _licensePlateImage,
                  onTapCamera: () => _pickImage(ImageSource.camera, false),
                  onTapGallery: () => _pickImage(ImageSource.gallery, false),
                ),
                const SizedBox(height: 24),
                
                // Submit button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitViolationReport,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildImageSection({
    required File? image,
    required VoidCallback onTapCamera,
    required VoidCallback onTapGallery,
  }) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: image != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.file(
                    image,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (image == _evidenceImage) {
                          _evidenceImage = null;
                        } else {
                          _licensePlateImage = null;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: onTapCamera,
                ),
                const SizedBox(width: 24),
                _buildImageSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: onTapGallery,
                ),
              ],
            ),
    );
  }
  
  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: Colors.blue.shade700,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 