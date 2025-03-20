import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:sutms/providers/auth_provider.dart';
import 'package:sutms/utils/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sutms/utils/api_constants.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  bool _hasScanned = false;
  Map<String, dynamic>? _vehicleData;
  String? _error;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && !_hasScanned && scanData.code != null) {
        _processQrCode(scanData.code!);
      }
    });
  }

  Future<void> _processQrCode(String code) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Pause camera while processing
      controller?.pauseCamera();
      
      // Send QR code to backend
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.scanQr}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token ${authProvider.token}',
        },
        body: json.encode({
          'qr_code': code,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        setState(() {
          _vehicleData = responseData;
          _hasScanned = true;
          _isProcessing = false;
        });
      } else {
        final responseData = json.decode(response.body);
        setState(() {
          _error = responseData['detail'] ?? 'Failed to process QR code';
          _isProcessing = false;
        });
        
        // Resume camera after error
        controller?.resumeCamera();
      }
    } catch (e) {
      setState(() {
        _error = 'Error processing QR code: ${e.toString()}';
        _isProcessing = false;
      });
      
      // Resume camera after error
      controller?.resumeCamera();
    }
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
      _vehicleData = null;
      _error = null;
    });
    
    // Resume camera
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await controller?.toggleFlash();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () async {
              await controller?.flipCamera();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: _hasScanned
                ? _buildVehicleDetails()
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      QRView(
                        key: qrKey,
                        onQRViewCreated: _onQRViewCreated,
                        overlay: QrScannerOverlayShape(
                          borderColor: AppTheme.primaryColor,
                          borderRadius: 10,
                          borderLength: 30,
                          borderWidth: 10,
                          cutOutSize: 300,
                        ),
                      ),
                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_error != null)
                        Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(20),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _resetScanner,
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Center(
                child: Text(
                  _hasScanned
                      ? 'Vehicle details retrieved successfully'
                      : 'Align the QR code within the frame to scan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails() {
    if (_vehicleData == null) {
      return const Center(
        child: Text('No vehicle data available'),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car,
                size: 60,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _vehicleData!['vehicle_number'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(_vehicleData!['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor(_vehicleData!['status']),
                ),
              ),
              child: Text(
                _vehicleData!['status'] ?? 'Unknown',
                style: TextStyle(
                  color: _getStatusColor(_vehicleData!['status']),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildInfoItem('Owner', _vehicleData!['owner_name'] ?? 'Unknown', Icons.person),
          const Divider(),
          _buildInfoItem('Model', _vehicleData!['model'] ?? 'Unknown', Icons.car_rental),
          const Divider(),
          _buildInfoItem('Registration Date', _vehicleData!['registration_date'] ?? 'Unknown', Icons.calendar_today),
          const Divider(),
          _buildInfoItem('Insurance Valid Until', _vehicleData!['insurance_valid_until'] ?? 'Unknown', Icons.security),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Another'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    switch (status.toLowerCase()) {
      case 'valid':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

