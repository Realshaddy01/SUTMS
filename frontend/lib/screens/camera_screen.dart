import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/vehicle.dart';
import '../models/violation.dart';
import '../providers/auth_provider.dart';
import '../providers/violation_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_indicator.dart';
import '../utils/validators.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  bool _isRecording = false;
  File? _capturedImage;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  bool _isProcessing = false;
  String? _error;
  bool _showForm = false;
  
  // Form fields
  Vehicle? _selectedVehicle;
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int? _selectedViolationTypeId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Vehicle && _selectedVehicle == null) {
      setState(() {
        _selectedVehicle = args;
        _licensePlateController.text = args.licensePlate;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() {
        _error = 'No cameras found';
      });
      return;
    }
    
    final camera = _isRearCameraSelected
        ? _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first)
        : _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first);
    
    setState(() {
      _isCameraInitialized = false;
    });
    
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    try {
      await _cameraController!.initialize();
      
      // Get zoom level constraints
      _minZoomLevel = await _cameraController!.getMinZoomLevel();
      _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize camera: ${e.toString()}';
      });
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = File(photo.path);
        _showForm = true;
      });
      
      // Load violation types if needed
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (violationProvider.violationTypes.isEmpty) {
        await violationProvider.fetchViolationTypes(authProvider.user!.token);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to take picture: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        setState(() {
          _capturedImage = File(pickedFile.path);
          _showForm = true;
        });
        
        // Load violation types if needed
        final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        if (violationProvider.violationTypes.isEmpty) {
          await violationProvider.fetchViolationTypes(authProvider.user!.token);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _recordViolation() async {
    if (_capturedImage == null || !_formKey.currentState!.validate() || _selectedViolationTypeId == null) {
      if (_selectedViolationTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a violation type')),
        );
      }
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      // Find vehicle ID by license plate if no vehicle is selected
      int vehicleId;
      if (_selectedVehicle != null) {
        vehicleId = _selectedVehicle!.id;
      } else {
        // Search for vehicle by license plate
        final searchResult = await Provider.of<VehicleProvider>(context, listen: false)
            .searchVehiclesByLicensePlate(authProvider.user!.token, _licensePlateController.text);
        
        if (searchResult == null || searchResult.isEmpty) {
          setState(() {
            _error = 'Vehicle not found with license plate: ${_licensePlateController.text}';
            _isProcessing = false;
          });
          return;
        }
        
        vehicleId = searchResult.first.id;
      }
      
      final success = await violationProvider.recordViolation(
        authProvider.user!.token,
        vehicleId: vehicleId,
        violationTypeId: _selectedViolationTypeId!,
        location: _locationController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        evidenceImage: _capturedImage,
        recordedById: authProvider.user!.id,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Violation recorded successfully')),
          );
          
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _error = violationProvider.error ?? 'Failed to record violation';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to record violation: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  void _resetCamera() {
    setState(() {
      _capturedImage = null;
      _showForm = false;
      _error = null;
      _selectedViolationTypeId = null;
      _locationController.text = '';
      _descriptionController.text = '';
      if (_selectedVehicle == null) {
        _licensePlateController.text = '';
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _licensePlateController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Violation'),
        actions: [
          if (!_showForm)
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () async {
                if (_cameraController != null && _cameraController!.value.isInitialized) {
                  setState(() {
                    _isFlashOn = !_isFlashOn;
                  });
                  await _cameraController!.setFlashMode(
                    _isFlashOn ? FlashMode.torch : FlashMode.off,
                  );
                }
              },
            ),
          if (!_showForm)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: () {
                setState(() {
                  _isRearCameraSelected = !_isRearCameraSelected;
                });
                _initializeCamera();
              },
            ),
        ],
      ),
      body: _isProcessing
          ? const LoadingIndicator(message: 'Processing...')
          : _error != null && !_isCameraInitialized && _capturedImage == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeCamera,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _showForm
                  ? _buildViolationForm()
                  : _buildCameraView(),
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Stack(
      children: [
        // Camera preview
        AspectRatio(
          aspectRatio: 1 / _cameraController!.value.aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
        
        // Zoom control
        Positioned(
          right: 16,
          top: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: 150,
                child: Slider(
                  value: _currentZoomLevel,
                  min: _minZoomLevel,
                  max: _maxZoomLevel,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: (value) async {
                    setState(() {
                      _currentZoomLevel = value;
                    });
                    await _cameraController!.setZoomLevel(value);
                  },
                ),
              ),
            ),
          ),
        ),
        
        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: const BoxDecoration(
              color: Colors.black54,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                  onPressed: _pickImageFromGallery,
                ),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white24,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.camera,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const IconButton(
                  icon: Icon(Icons.info_outline, color: Colors.white, size: 32),
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViolationForm() {
    final violationProvider = Provider.of<ViolationProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            
            // Evidence image preview
            if (_capturedImage != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _capturedImage!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Evidence Image',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetCamera,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retake'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // License Plate
            CustomTextField(
              controller: _licensePlateController,
              labelText: 'License Plate',
              prefixIcon: Icons.directions_car,
              enabled: _selectedVehicle == null,
              validator: Validators.validateRequired,
              helperText: _selectedVehicle != null ? 'Vehicle pre-selected from QR scan' : null,
            ),
            const SizedBox(height: 16),
            
            // Violation Type
            const Text(
              'Violation Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (violationProvider.violationTypes.isEmpty)
              const Center(
                child: Text('No violation types available'),
              )
            else
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: const Icon(Icons.warning),
                  ),
                  hint: const Text('Select Violation Type'),
                  value: _selectedViolationTypeId,
                  items: violationProvider.violationTypes.map((ViolationType type) {
                    return DropdownMenuItem<int>(
                      value: type.id,
                      child: Text('${type.name} (${type.formattedFine})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedViolationTypeId = value;
                    });
                  },
                ),
              ),
            const SizedBox(height: 16),
            
            // Location
            CustomTextField(
              controller: _locationController,
              labelText: 'Location',
              prefixIcon: Icons.location_on,
              validator: Validators.validateRequired,
            ),
            const SizedBox(height: 16),
            
            // Description
            CustomTextField(
              controller: _descriptionController,
              labelText: 'Description (Optional)',
              prefixIcon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Submit Button
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Record Violation',
                    onPressed: _recordViolation,
                    isLoading: _isProcessing,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cancel Button
            if (!_isProcessing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
