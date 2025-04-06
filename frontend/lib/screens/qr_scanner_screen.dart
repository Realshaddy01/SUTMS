import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  Map<String, dynamic>? _scanResult;
  
  final _apiService = ApiService();

  // In order to get hot reload working, we need to pause the camera if the platform
  // is Android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _processQRCode(scanData.code!);
      }
    });
  }

  Future<void> _processQRCode(String data) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final Map<String, dynamic> result = await _apiService.verifyQRCode(data);
      
      setState(() {
        _scanResult = result;
      });
      
      controller?.pauseCamera();
      
    } catch (e) {
      print('Error processing QR code: $e');
      
      setState(() {
        _scanResult = {
          'success': false,
          'message': e.toString(),
        };
      });
      
      controller?.pauseCamera();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _toggleFlash() async {
    await controller?.toggleFlash();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _resumeScanning() {
    setState(() {
      _scanResult = null;
    });
    controller?.resumeCamera();
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Theme.of(context).primaryColor,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: 300,
          ),
        ),
        // Controls
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flash toggle button
              FloatingActionButton(
                heroTag: 'flash',
                onPressed: _toggleFlash,
                backgroundColor: Colors.white.withOpacity(0.7),
                child: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.black,
                ),
                mini: true,
              ),
            ],
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
        // Instructions
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: Colors.black54,
            child: const Text(
              'Scan the QR code on the vehicle registration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final bool isSuccess = _scanResult?['success'] ?? false;
    final vehicleData = _scanResult?['vehicle'];
    
    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success/Error icon
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  size: 60,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  isSuccess ? 'Vehicle Verified' : 'Verification Failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Message
                Text(
                  _scanResult?['message'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Divider(),
                // Vehicle details
                if (isSuccess && vehicleData != null) ...[
                  ListTile(
                    title: const Text('License Plate'),
                    subtitle: Text(vehicleData['license_plate'] ?? ''),
                    leading: const Icon(Icons.directions_car),
                  ),
                  ListTile(
                    title: const Text('Owner'),
                    subtitle: Text(vehicleData['owner_name'] ?? ''),
                    leading: const Icon(Icons.person),
                  ),
                  ListTile(
                    title: const Text('Vehicle Details'),
                    subtitle: Text('${vehicleData['make'] ?? ''} ${vehicleData['model'] ?? ''} (${vehicleData['color'] ?? ''})'),
                    leading: const Icon(Icons.info),
                  ),
                  ListTile(
                    title: const Text('Registration Status'),
                    subtitle: Text(
                      vehicleData['is_registration_valid'] == true
                          ? 'Valid until ${vehicleData['registration_expiry'] ?? ''}'
                          : 'Expired',
                      style: TextStyle(
                        color: vehicleData['is_registration_valid'] == true
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: const Icon(Icons.assignment),
                  ),
                ],
                const SizedBox(height: 16),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _resumeScanning,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    ),
                    if (isSuccess && vehicleData != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to report violation screen
                          Navigator.of(context).pushReplacementNamed(
                            '/violation-create',
                            arguments: {'vehicleData': vehicleData},
                          );
                        },
                        icon: const Icon(Icons.report),
                        label: const Text('Report Violation'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
      ),
      body: _scanResult != null
          ? _buildResultView()
          : _buildScannerView(),
    );
  }
}
