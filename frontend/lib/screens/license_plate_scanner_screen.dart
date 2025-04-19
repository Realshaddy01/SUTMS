import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../widgets/expandable_violation_card.dart';
import '../utils/ui_utils.dart';

class LicensePlateScanner extends StatefulWidget {
  const LicensePlateScanner({super.key});

  @override
  _LicensePlateScannerState createState() => _LicensePlateScannerState();
}

class _LicensePlateScannerState extends State<LicensePlateScanner> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _flashOn = false;
  File? _image;
  Map<String, dynamic>? _scanResult;
  final ApiService _apiService = ApiService();
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(cameras[0], ResolutionPreset.high);
        await _controller.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      } else {
        showSnackBar(context, "No cameras found on this device");
      }
    } catch (e) {
      showSnackBar(context, "Error initializing camera: $e");
    }
  }
  
  @override
  void dispose() {
    if (_isCameraInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isProcessing) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final XFile image = await _controller.takePicture();
      setState(() {
        _image = File(image.path);
      });
      await _processImage();
    } catch (e) {
      showSnackBar(context, "Error taking picture: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    if (_isProcessing) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isProcessing = true;
      });
      await _processImage();
    }
  }
  
  Future<void> _processImage() async {
    if (_image == null) {
      setState(() {
        _isProcessing = false;
      });
      return;
    }
    
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool hasInternet = connectivityResult != ConnectivityResult.none;
      
      // Process image with OCR
      final result = await _apiService.scanLicensePlate(
        _image!, 
        hasInternet: hasInternet
      );
      
      setState(() {
        _scanResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      showSnackBar(context, "Error processing image: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  void _toggleFlash() async {
    if (!_isCameraInitialized) return;
    
    setState(() {
      _flashOn = !_flashOn;
    });
    
    await _controller.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off
    );
  }
  
  Future<void> _reportViolation(int vehicleId, String licensePlate) async {
    // Navigate to violation report screen with vehicle info
    final result = await Navigator.pushNamed(
      context,
      '/report-violation',
      arguments: {
        'vehicle_id': vehicleId,
        'license_plate': licensePlate,
      },
    );
    
    if (result == true) {
      // Refresh vehicle data after successful report
      if (_scanResult != null && _scanResult!['vehicle'] != null) {
        final vehicleId = _scanResult!['vehicle']['id'];
        try {
          final violations = await _apiService.getVehicleViolations(vehicleId);
          setState(() {
            _scanResult!['recent_violations'] = violations['violations'].take(3).toList();
            _scanResult!['vehicle']['total_violations'] = violations['total_count'];
          });
        } catch (e) {
          print("Error refreshing violations: $e");
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized && _scanResult == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('License Plate Scanner')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Plate Scanner'),
        actions: [
          if (_scanResult == null)
            IconButton(
              icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _scanResult != null
                ? _buildResultView()
                : _buildCameraView(),
          ),
        ],
      ),
      floatingActionButton: _scanResult == null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'gallery',
                  onPressed: _isProcessing ? null : _pickImage,
                  tooltip: 'Pick from Gallery',
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'camera',
                  onPressed: _isProcessing ? null : _takePicture,
                  tooltip: 'Take Photo',
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _scanResult = null;
                  _image = null;
                });
              },
              tooltip: 'Scan Another',
              child: const Icon(Icons.refresh),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  
  Widget _buildCameraView() {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_controller),
        ),
        // License plate target overlay
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.25,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.black54,
            child: const Text(
              'Align license plate within the box',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Scanning license plate...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildResultView() {
    final result = _scanResult!;
    final success = result['success'] ?? false;
    
    if (!success) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              result['message'] ?? 'Failed to recognize license plate',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Confidence: ${((result['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }
    
    final vehicle = result['vehicle'];
    final violations = result['recent_violations'] ?? [];
    
    if (vehicle == null) {
      // License plate recognized but vehicle not found
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Vehicle not found in database',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'License plate recognized:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result['license_plate'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Confidence: ${((result['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    // Vehicle found - show details and violations
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // License plate section
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result['license_plate'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Vehicle details section
          _buildSectionTitle('Vehicle Details'),
          _buildDetailRow('Make & Model', '${vehicle['make']} ${vehicle['model']}'),
          _buildDetailRow('Year', '${vehicle['year']}'),
          _buildDetailRow('Color', '${vehicle['color']}'),
          _buildDetailRow('Owner', '${vehicle['owner_name']}'),
          const SizedBox(height: 16),
          
          // Tax clearance status
          _buildStatusCard(
            icon: Icons.receipt_long,
            title: 'Tax Clearance',
            status: vehicle['tax_clearance']['is_cleared'] ? 'Cleared' : 'Not Cleared',
            isPositive: vehicle['tax_clearance']['is_cleared'],
            details: vehicle['tax_clearance']['is_cleared']
                ? 'Valid until ${vehicle['tax_clearance']['expiry_date']}'
                : 'Tax not cleared',
          ),
          const SizedBox(height: 12),
          
          // Theft status
          _buildStatusCard(
            icon: Icons.security,
            title: 'Theft Status',
            status: vehicle['is_stolen'] ? 'REPORTED STOLEN' : 'No Reports',
            isPositive: !vehicle['is_stolen'],
            details: vehicle['is_stolen']
                ? 'This vehicle has been reported as stolen'
                : 'No theft reports for this vehicle',
          ),
          const SizedBox(height: 24),
          
          // Violations section
          _buildSectionTitle('Recent Violations'),
          if (violations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No recent violations recorded'),
            )
          else
            for (var violation in violations)
              ExpandableViolationCard(violation: violation),
              
          if ((vehicle['total_violations'] ?? 0) > 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to full history
                    Navigator.pushNamed(
                      context,
                      '/vehicle-violations',
                      arguments: {
                        'vehicle_id': vehicle['id'],
                        'license_plate': result['license_plate'],
                      },
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View Full History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade700),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          
          // Report new violation button
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _reportViolation(vehicle['id'], result['license_plate']),
              icon: const Icon(Icons.report_problem),
              label: const Text('Report New Violation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String status,
    required bool isPositive,
    required String details,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPositive ? Colors.green.shade300 : Colors.red.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 42,
              color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
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