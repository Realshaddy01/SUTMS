import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/custom_text_field.dart';
import '../utils/validators.dart';
import 'package:share_plus/share_plus.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({Key? key}) : super(key: key);

  @override
  _VehicleScreenState createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  bool _isLoading = true;
  String? _error;
  Vehicle? _selectedVehicle;

  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _registrationNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      if (authProvider.user?.token == null) {
        throw Exception("Authentication token not found");
      }
      
      await vehicleProvider.fetchVehicles(authProvider.user!.token!);
    } catch (e) {
      setState(() {
        _error = 'Failed to load vehicles. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddVehicleDialog() {
    // Reset form fields
    _licensePlateController.clear();
    _makeController.clear();
    _modelController.clear();
    _yearController.clear();
    _colorController.clear();
    _registrationNumberController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Vehicle'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _licensePlateController,
                  labelText: 'License Plate',
                  prefixIcon: Icons.directions_car,
                  validator: Validators.validateLicensePlateAdapter,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _makeController,
                  labelText: 'Make',
                  prefixIcon: Icons.business,
                  validator: Validators.validateRequiredAdapter,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _modelController,
                  labelText: 'Model',
                  prefixIcon: Icons.car_repair,
                  validator: Validators.validateRequiredAdapter,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _yearController,
                  labelText: 'Year',
                  prefixIcon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: Validators.validateYearAdapter,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _colorController,
                  labelText: 'Color',
                  prefixIcon: Icons.color_lens,
                  validator: Validators.validateRequiredAdapter,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _registrationNumberController,
                  labelText: 'Registration Number',
                  prefixIcon: Icons.article,
                  validator: Validators.validateRequiredAdapter,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _addVehicle();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addVehicle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      if (authProvider.user?.token == null || authProvider.user?.id == null) {
        throw Exception("Authentication token or user ID not found");
      }
      
      final success = await vehicleProvider.addVehicle(
        authProvider.user!.token!,
        ownerId: authProvider.user!.id,
        licensePlate: _licensePlateController.text.trim(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        color: _colorController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim(),
        vehicleTypeId: 1, // Default to car type
      );
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vehicleProvider.error ?? 'Failed to add vehicle')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to add vehicle. Please try again.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVehicleDetails(Vehicle vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    vehicle.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailSection(vehicle),
              const SizedBox(height: 16),
              _buildActionButtons(vehicle),
              const SizedBox(height: 24),
              _buildQrCodeSection(vehicle),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQrCodeSection(Vehicle vehicle) {
    if (vehicle.qrCodeUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle QR Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  vehicle.qrCodeUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('QR code not available'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _shareQRCode(vehicle),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _generateQRCode(vehicle.id),
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
              ),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle QR Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No QR code available',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _generateQRCode(vehicle.id),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Generate QR Code'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }
  
  Future<void> _generateQRCode(int vehicleId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      if (authProvider.user?.token == null) {
        throw Exception("Authentication token not found");
      }
      
      final qrCodeUrl = await vehicleProvider.generateQRCode(
        authProvider.user!.token!,
        vehicleId,
      );
      
      if (qrCodeUrl != null) {
        // Refresh vehicles to get updated data
        await vehicleProvider.fetchVehicles(authProvider.user!.token!);
        
        // Find the updated vehicle
        final updatedVehicle = vehicleProvider.vehicles.firstWhere(
          (v) => v.id == vehicleId,
          orElse: () => _selectedVehicle!,
        );
        
        // Show vehicle details again with updated QR code
        if (mounted) {
          setState(() {
            _selectedVehicle = updatedVehicle;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate QR code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate QR code: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _shareQRCode(Vehicle vehicle) async {
    if (vehicle.qrCodeUrl == null) return;
    
    try {
      await Share.share(
        'Vehicle QR Code for ${vehicle.licensePlate} - ${vehicle.make} ${vehicle.model}\n\nScan this QR code to verify vehicle information.',
        subject: 'Vehicle QR Code - ${vehicle.licensePlate}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share QR code: ${e.toString()}')),
      );
    }
  }
  
  Widget _buildActionButtons(Vehicle vehicle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.edit,
          label: 'Edit',
          onTap: () {
            // Edit vehicle function
          },
        ),
        _buildActionButton(
          icon: Icons.qr_code_scanner,
          label: 'Scan QR',
          onTap: () {
            Navigator.of(context).pushNamed('/qr-scan');
          },
        ),
        _buildActionButton(
          icon: Icons.report_problem,
          label: 'Violations',
          onTap: () {
            Navigator.of(context).pushNamed(
              '/vehicle-violations',
              arguments: {
                'vehicle_id': vehicle.id,
                'license_plate': vehicle.licensePlate,
              },
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailSection(Vehicle vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('License Plate', vehicle.licensePlate),
        const SizedBox(height: 8),
        _buildDetailRow('Make', vehicle.make ?? 'Not available'),
        const SizedBox(height: 8),
        _buildDetailRow('Model', vehicle.model ?? 'Not available'),
        const SizedBox(height: 8),
        _buildDetailRow('Year', vehicle.year.toString()),
        const SizedBox(height: 8),
        _buildDetailRow('Color', vehicle.color ?? 'Not available'),
        const SizedBox(height: 8),
        _buildDetailRow('Registration', vehicle.registrationNumber ?? 'Not available'),
        if (vehicle.registrationExpiry != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow('Registration Expiry', 
            vehicle.registrationExpiry.toString().substring(0, 10)),
        ],
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = Provider.of<VehicleProvider>(context);
    final vehicles = vehicleProvider.vehicles;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVehicles,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : vehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.directions_car,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No vehicles found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first vehicle to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/add-vehicle'),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Vehicle'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = vehicles[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _showVehicleDetails(vehicle),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.directions_car,
                                        size: 36,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${vehicle.make} ${vehicle.model}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${vehicle.year} • ${vehicle.color}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          vehicle.licensePlate,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: vehicles.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/add-vehicle'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
