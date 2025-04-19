import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/ml_model_service.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/plate_result_card.dart';
import '../screens/violation_form_screen.dart';

class OCRCameraScreen extends StatefulWidget {
  const OCRCameraScreen({Key? key}) : super(key: key);

  @override
  _OCRCameraScreenState createState() => _OCRCameraScreenState();
}

class _OCRCameraScreenState extends State<OCRCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isBackCamera = true;
  File? _imageFile;
  Map<String, dynamic>? _ocrResult;
  
  final _apiService = ApiService();
  late MLModelService _mlModelService;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _mlModelService = MLModelService();
    _mlModelService.loadModel();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    final CameraController? cameraController = _controller;
    
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeCamera() async {
    // Get available cameras
    _cameras = await availableCameras();
    
    if (_cameras == null || _cameras!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No camera available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Initialize the camera controller
    CameraDescription cameraToUse = _cameras!.firstWhere(
      (camera) => camera.lensDirection == (_isBackCamera ? CameraLensDirection.back : CameraLensDirection.front),
      orElse: () => _cameras!.first,
    );
    
    _controller = CameraController(
      cameraToUse,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    try {
      await _controller!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _toggleCamera() async {
    setState(() {
      _isBackCamera = !_isBackCamera;
      _isCameraInitialized = false;
    });
    
    if (_controller != null) {
      await _controller!.dispose();
    }
    
    await _initializeCamera();
  }
  
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not initialized'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_isProcessing) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final XFile imageFile = await _controller!.takePicture();
      await _processImage(File(imageFile.path));
    } catch (e) {
      print('Error taking picture: $e');
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        await _processImage(File(image.path));
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
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _imageFile = imageFile;
      _isProcessing = true;
    });
    
    try {
      // First try to use our local ML model
      final localResult = await _mlModelService.recognizeLicensePlate(imageFile);
      if (localResult != null && localResult.isNotEmpty) {
        setState(() {
          _ocrResult = {'license_plate': localResult};
          _isProcessing = false;
        });
        
        // If license plate detected, search for vehicle
        await _searchVehicle(localResult);
        return;
      }
      
      // Fallback to API if local model fails
      final result = await _apiService.detectLicensePlateWithoutToken(imageFile);
      
      setState(() {
        _ocrResult = result;
        _isProcessing = false;
      });
      
      // If license plate detected, search for vehicle
      if (result['license_plate'] != null) {
        await _searchVehicle(result['license_plate']);
      }
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _searchVehicle(String licensePlate) async {
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    
    try {
      await vehicleProvider.searchVehicleByLicensePlate(licensePlate);
    } catch (e) {
      print('Error searching vehicle: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching vehicle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _createViolation() {
    if (_ocrResult != null && _ocrResult!['license_plate'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViolationFormScreen(
            licensePlate: _ocrResult!['license_plate'],
            imagePath: _imageFile?.path,
            vehicleId: Provider.of<VehicleProvider>(context, listen: false).currentVehicle?.id,
          ),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Plate Scanner'),
        actions: [
          IconButton(
            icon: Icon(_isBackCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: _toggleCamera,
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isProcessing,
        loadingText: 'Processing image...',
        child: Column(
          children: [
            // Camera preview
            Expanded(
              child: _isCameraInitialized
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CameraPreview(_controller!),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            
            // Results display
            if (_ocrResult != null && _imageFile != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: PlateResultCard(
                  plateText: _ocrResult!['license_plate'] ?? 'Unknown',
                  confidence: _ocrResult!['confidence'] ?? 0.0,
                  imagePath: _imageFile!.path,
                  onCreateViolation: _createViolation,
                ),
              ),
            ],
            
            // Camera controls
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: _pickImageFromGallery,
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.photo_library),
                  ),
                  FloatingActionButton(
                    onPressed: _takePicture,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.camera),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
