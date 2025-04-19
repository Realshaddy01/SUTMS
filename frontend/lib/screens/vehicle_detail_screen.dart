import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/vehicle_qr_code.dart';
import '../utils/constants.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;

  const VehicleDetailScreen({
    Key? key,
    required this.vehicleId,
  }) : super(key: key);

  @override
  _VehicleDetailScreenState createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  bool _isLoading = true;
  Vehicle? _vehicle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  Future<void> _loadVehicleData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      final vehicle = await vehicleProvider.getVehicleById(widget.vehicleId);
      
      setState(() {
        _vehicle = vehicle;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load vehicle data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _navigateToReportViolation() {
    if (_vehicle == null) return;
    
    Navigator.of(context).pushNamed(
      '/violation-form',
      arguments: {
        'licensePlate': _vehicle!.licensePlate,
        'vehicleId': _vehicle!.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        elevation: Constants.appBarElevation,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVehicleData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildVehicleDetails(),
    );
  }

  Widget _buildVehicleDetails() {
    if (_vehicle == null) {
      return const Center(child: Text('No vehicle data found'));
    }

    final vehicle = _vehicle!;
    final isRegistrationValid = vehicle.isRegistrationValid;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Constants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle info card
          Card(
            elevation: Constants.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        size: 50,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.licensePlate,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '${vehicle.make} ${vehicle.model} (${vehicle.color})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Registration Status
                  ListTile(
                    title: const Text('Registration Status'),
                    subtitle: Text(
                      isRegistrationValid
                          ? 'Valid until ${vehicle.registrationExpiry}'
                          : 'Expired',
                      style: TextStyle(
                        color: isRegistrationValid ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: Icon(
                      isRegistrationValid ? Icons.check_circle : Icons.cancel,
                      color: isRegistrationValid ? Colors.green : Colors.red,
                    ),
                  ),
                  
                  // Owner Info
                  ListTile(
                    title: const Text('Owner'),
                    subtitle: Text(vehicle.ownerName),
                    leading: const Icon(Icons.person),
                  ),
                  
                  // Vehicle Type
                  ListTile(
                    title: const Text('Vehicle Type'),
                    subtitle: Text(vehicle.type),
                    leading: const Icon(Icons.category),
                  ),
                  
                  // Year
                  ListTile(
                    title: const Text('Year'),
                    subtitle: Text(vehicle.year.toString()),
                    leading: const Icon(Icons.date_range),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // QR Code Section
          Card(
            elevation: Constants.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: VehicleQRCode(
                vehicle: vehicle,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Violations Section
          Card(
            elevation: Constants.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Violation History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        '/vehicle-violations',
                        arguments: {
                          'vehicle_id': vehicle.id,
                          'license_plate': vehicle.licensePlate,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: const Text('View Violation History'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 