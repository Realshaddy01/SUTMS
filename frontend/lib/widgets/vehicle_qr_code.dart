import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';

class VehicleQRCode extends StatefulWidget {
  final Vehicle vehicle;
  final bool showActions;
  
  const VehicleQRCode({
    Key? key,
    required this.vehicle,
    this.showActions = true,
  }) : super(key: key);

  @override
  _VehicleQRCodeState createState() => _VehicleQRCodeState();
}

class _VehicleQRCodeState extends State<VehicleQRCode> {
  bool _isLoading = false;
  String? _error;
  
  Future<void> _generateQRCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      if (authProvider.user?.token == null) {
        throw Exception('Authentication token not found');
      }
      
      await vehicleProvider.generateQRCode(
        authProvider.user!.token!,
        widget.vehicle.id,
      );
      
      // Refresh vehicles list to get updated QR code URL
      await vehicleProvider.fetchVehicles(authProvider.user!.token!);
      
    } catch (e) {
      setState(() {
        _error = 'Failed to generate QR code: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _shareQRCode() async {
    if (widget.vehicle.qrCodeUrl == null) return;
    
    try {
      await Share.share(
        'Vehicle QR Code for ${widget.vehicle.licensePlate}\n${widget.vehicle.make} ${widget.vehicle.model}\n\nScan this QR code to verify the vehicle information.',
        subject: 'Vehicle QR Code - ${widget.vehicle.licensePlate}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share QR code: ${e.toString()}')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.vehicle.qrCodeUrl != null) ...[
          Container(
            width: 250,
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : QrImageView(
                    data: 'SUTMS:${widget.vehicle.licensePlate}:${widget.vehicle.id}',
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    embeddedImage: const AssetImage('assets/images/logo_small.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(40, 40),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (widget.showActions) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareQRCode,
                  tooltip: 'Share QR Code',
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () {
                    // Implement printing functionality if needed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Printing not implemented yet')),
                    );
                  },
                  tooltip: 'Print QR Code',
                ),
              ],
            ),
          ],
        ] else ...[
          SizedBox(
            width: 250,
            height: 250,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No QR code available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generateQRCode,
                          child: const Text('Generate QR Code'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ],
    );
  }
} 