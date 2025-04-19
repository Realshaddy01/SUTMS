import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class LicensePlateScannerScreen extends StatefulWidget {
  const LicensePlateScannerScreen({Key? key}) : super(key: key);

  @override
  _LicensePlateScannerScreenState createState() => _LicensePlateScannerScreenState();
}

class _LicensePlateScannerScreenState extends State<LicensePlateScannerScreen> {
  late CameraController _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _plateText;
  Map<String, dynamic>? _vehicleInfo;
  File? _imageFile;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }
  
  Future<void> _takePicture() async {
    if (!_isCameraInitialized) return;
    
    try {
      setState(() {
        _isProcessing = true;
        _plateText = null;
        _vehicleInfo = null;
      });
      
      final XFile photo = await _cameraController.takePicture();
      _imageFile = File(photo.path);
      
      await _processImage(_imageFile!);
    } catch (e) {
      print('Error taking picture: $e');
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }
  
  Future<void> _pickImage() async {
    try {
      setState(() {
        _isProcessing = true;
        _plateText = null;
        _vehicleInfo = null;
      });
      
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
      
      if (photo != null) {
        _imageFile = File(photo.path);
        await _processImage(_imageFile!);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  
  Future<void> _processImage(File imageFile) async {
    try {
      final apiService = ApiService();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user?.token == null) {
        throw Exception('You must be logged in');
      }
      
      final result = await apiService.detectLicensePlate(
        imageFile, 
        authProvider.user!.token!
      );
      
      setState(() {
        _plateText = result['license_plate'];
        _vehicleInfo = result['vehicle_info'];
        _isProcessing = false;
      });
      
      if (_vehicleInfo != null) {
        _showVehicleInfoBottomSheet();
      }
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }
  
  void _showVehicleInfoBottomSheet() {
    if (_vehicleInfo == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => _buildVehicleInfoPanel(scrollController),
      ),
    );
  }
  
  Widget _buildVehicleInfoPanel(ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vehicle Information',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const Divider(),
          _buildInfoRow('License Plate', _vehicleInfo!['license_plate']),
          _buildInfoRow('Make', _vehicleInfo!['make']),
          _buildInfoRow('Model', _vehicleInfo!['model']),
          _buildInfoRow('Owner', _vehicleInfo!['owner_name']),
          _buildInfoRow('Year', _vehicleInfo!['year'].toString()),
          _buildInfoRow('Color', _vehicleInfo!['color']),
          _buildInfoRow(
            'Registration Status', 
            _vehicleInfo!['registration_status'] ? 'Valid' : 'Expired',
            valueColor: _vehicleInfo!['registration_status'] ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to violation report screen with vehicle data
              Navigator.of(context).pushNamed(
                '/report-violation',
                arguments: {'vehicleId': _vehicleInfo!['id']},
              );
            },
            child: const Text('Report Violation'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Plate Scanner'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_isCameraInitialized)
                  CameraPreview(_cameraController)
                else if (_imageFile != null)
                  Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                else
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'Camera not available',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                
                // Overlay for plate detection
                if (_plateText != null)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Detected: $_plateText',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                
                // Loading indicator
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          
          // Controls section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: _isProcessing ? null : _pickImage,
                      iconSize: 36,
                      color: Theme.of(context).primaryColor,
                    ),
                    FloatingActionButton(
                      onPressed: _isProcessing ? null : _takePicture,
                      child: const Icon(Icons.camera_alt),
                    ),
                    IconButton(
                      icon: const Icon(Icons.rotate_90_degrees_ccw),
                      onPressed: _isProcessing ? null : () {
                        // Switch camera logic (if multiple cameras available)
                      },
                      iconSize: 36,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Position vehicle license plate in the frame',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
