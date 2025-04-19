import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/api_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  Map<String, dynamic>? _scanResult;
  
  final _apiService = ApiService();

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

  Widget _buildScannerView() {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 200.0
        : 300.0;

    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Theme.of(context).colorScheme.secondary,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: scanArea,
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
                mini: true,
                child: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.black,
                ),
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

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      if (_isScanning && !_isProcessing && scanData.code != null) {
        _processQRCode(scanData.code!);
      }
    });
  }

  Future<void> _processQRCode(String data) async {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final Map<String, dynamic> result = await _apiService.verifyQRCode(data);
      
      if (!mounted) return;
      
      setState(() {
        _scanResult = result;
      });
      
      controller?.pauseCamera();
      
    } catch (e) {
      debugPrint('Error processing QR code: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      
      setState(() {
        _scanResult = {
          'success': false,
          'message': e.toString(),
        };
      });
      
      controller?.pauseCamera();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await controller?.toggleFlash();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  void _resumeScanning() {
    setState(() {
      _isScanning = true;
      _scanResult = null;
    });
    controller?.resumeCamera();
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
