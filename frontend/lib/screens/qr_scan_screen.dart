import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:convert';
import '../providers/vehicle_provider.dart';
import '../widgets/loading_indicator.dart';
import '../models/vehicle.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({Key? key}) : super(key: key);

  @override
  _QRScanScreenState createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isScanning = true;
  bool _isLoading = false;
  String? _error;
  Vehicle? _scannedVehicle;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Vehicle QR Code'),
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
      body: _isLoading
          ? const LoadingIndicator(message: 'Verifying vehicle...')
          : _scannedVehicle != null
              ? _buildVehicleDetailsView()
              : Stack(
                  children: [
                    _buildQrView(context),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Position the QR code in the scanning area',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isScanning = !_isScanning;
                                });
                                if (_isScanning) {
                                  controller?.resumeCamera();
                                } else {
                                  controller?.pauseCamera();
                                }
                              },
                              child: Text(_isScanning ? 'Pause' : 'Resume'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 200.0
        : 300.0;
    
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).primaryColor,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    
    controller.scannedDataStream.listen((scanData) async {
      if (_isScanning && scanData.code != null) {
        setState(() {
          _isScanning = false;
          _isLoading = true;
          _error = null;
        });
        controller.pauseCamera();
        
        try {
          // Parse the QR code data
          final qrData = jsonDecode(scanData.code!);
          await _verifyVehicle(qrData);
        } catch (e) {
          setState(() {
            _isLoading = false;
            _error = 'Invalid QR code format. Please try again.';
            _isScanning = true;
          });
          controller.resumeCamera();
        }
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool permission) {
    if (!permission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
    }
  }

  Future<void> _verifyVehicle(Map<String, dynamic> qrData) async {
    try {
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      // Get QR data as a string (JSON stringified)
      final String qrDataString = json.encode(qrData);
      
      final vehicle = await vehicleProvider.verifyVehicleByQRData(qrDataString);
      
      setState(() {
        _isLoading = false;
        _scannedVehicle = vehicle;
      });
      
      if (_scannedVehicle == null) {
        setState(() {
          _error = vehicleProvider.error ?? 'Failed to verify vehicle';
          _isScanning = true;
        });
        controller?.resumeCamera();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to verify vehicle: ${e.toString()}';
        _isScanning = true;
      });
      controller?.resumeCamera();
    }
  }

  Widget _buildVehicleDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vehicle Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Divider(),
                  _buildDetailRow('License Plate', _scannedVehicle?.licensePlate),
                  _buildDetailRow('Make', _scannedVehicle?.make),
                  _buildDetailRow('Model', _scannedVehicle?.model),
                  _buildDetailRow('Year', _scannedVehicle?.year.toString()),
                  _buildDetailRow('Color', _scannedVehicle?.color),
                  _buildDetailRow('Owner', _scannedVehicle?.ownerName),
                  _buildDetailRow('Registration', _scannedVehicle?.registrationNumber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _scannedVehicle = null;
                    _isScanning = true;
                  });
                  controller?.resumeCamera();
                },
                child: const Text('Scan Another'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not available',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
