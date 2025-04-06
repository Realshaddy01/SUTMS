import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_indicator.dart';
import '../utils/validators.dart';

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
      
      await vehicleProvider.fetchVehicles(authProvider.user!.token);
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
                  validator: Validators.validateRequired,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _makeController,
                  labelText: 'Make',
                  prefixIcon: Icons.business,
                  validator: Validators.validateRequired,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _modelController,
                  labelText: 'Model',
                  prefixIcon: Icons.car_repair,
                  validator: Validators.validateRequired,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _yearController,
                  labelText: 'Year',
                  prefixIcon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: Validators.validateYear,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _colorController,
                  labelText: 'Color',
                  prefixIcon: Icons.color_lens,
                  validator: Validators.validateRequired,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _registrationNumberController,
                  labelText: 'Registration Number',
                  prefixIcon: Icons.article,
                  validator: Validators.validateRequired,
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
      
      final success = await vehicleProvider.addVehicle(
        authProvider.user!.token,
        ownerId: authProvider.user!.id,
        licensePlate: _licensePlateController.text.trim(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        color: _colorController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim(),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Vehicle Image
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          size: 80,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Vehicle Details
                    const Text(
                      'Vehicle Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('License Plate', vehicle.licensePlate),
                    _buildDetailRow('Make', vehicle.make),
                    _buildDetailRow('Model', vehicle.model),
                    _buildDetailRow('Year', vehicle.year.toString()),
                    _buildDetailRow('Color', vehicle.color),
                    _buildDetailRow('Registration', vehicle.registrationNumber),
                    const SizedBox(height: 24),
                    
                    // QR Code
                    if (vehicle.qrCodeUrl != null) ...[
                      const Text(
                        'QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.network(
                                vehicle.qrCodeUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text('Failed to load QR code'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use this QR code for quick verification',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('QR code not available'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _generateQRCode(vehicle.id);
                              },
                              child: const Text('Generate QR Code'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditVehicleDialog(vehicle);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(vehicle);
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateQRCode(int vehicleId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      final qrCodeUrl = await vehicleProvider.getVehicleQRCode(
        authProvider.user!.token,
        vehicleId,
      );
      
      if (qrCodeUrl != null) {
        // Refresh vehicles to get updated data
        await vehicleProvider.fetchVehicles(authProvider.user!.token);
        
        // Find the updated vehicle
        final updatedVehicle = vehicleProvider.vehicles.firstWhere(
          (v) => v.id == vehicleId,
          orElse: () => _selectedVehicle!,
        );
        
        // Show vehicle details again with updated QR code
        if (mounted) {
          _showVehicleDetails(updatedVehicle);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate QR code')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to generate QR code. Please try again.';
      });
      
      if (mounted) {
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

  void _showEditVehicleDialog(Vehicle vehicle) {
    // Pre-fill form fields with current vehicle data
    _makeController.text = vehicle.make;
    _modelController.text = vehicle.model;
    _yearController.text = vehicle.year.toString();
    _colorController.text = vehicle.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Vehicle'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display license plate but don't allow editing
                ListTile(
                  title: const Text('License Plate'),
                  subtitle: Text(vehicle.licensePlate),
                  leading: const Icon(Icons.directions_car),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _makeController,
                  labelText: 'Make',
                  prefixIcon: Icons.business,
                  validator: Validators.validateRequired,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _modelController,
                  labelText: 'Model',
                  prefixIcon: Icons.car_repair,
                  validator: Validators.validateRequired,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _yearController,
                  labelText: 'Year',
                  prefixIcon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: Validators.validateYear,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _colorController,
                  labelText: 'Color',
                  prefixIcon: Icons.color_lens,
                  validator: Validators.validateRequired,
                ),
                // Display registration number but don't allow editing
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Registration Number'),
                  subtitle: Text(vehicle.registrationNumber),
                  leading: const Icon(Icons.article),
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
                await _updateVehicle(vehicle.id);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVehicle(int vehicleId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      final success = await vehicleProvider.updateVehicle(
        authProvider.user!.token,
        vehicleId,
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        color: _colorController.text.trim(),
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle updated successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vehicleProvider.error ?? 'Failed to update vehicle')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update vehicle. Please try again.';
      });
      
      if (mounted) {
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

  void _showDeleteConfirmation(Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text(
          'Are you sure you want to delete ${vehicle.make} ${vehicle.model} (${vehicle.licensePlate})? This action cannot be undone.',
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
              Navigator.of(context).pop();
              await _deleteVehicle(vehicle.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVehicle(int vehicleId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      final success = await vehicleProvider.deleteVehicle(
        authProvider.user!.token,
        vehicleId,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vehicleProvider.error ?? 'Failed to delete vehicle')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to delete vehicle. Please try again.';
      });
      
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = Provider.of<VehicleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading vehicles...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVehicles,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVehicles,
                  child: vehicleProvider.vehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.directions_car,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No vehicles registered',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showAddVehicleDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Vehicle'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: vehicleProvider.vehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = vehicleProvider.vehicles[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: VehicleCard(
                                vehicle: vehicle,
                                onTap: () => _showVehicleDetails(vehicle),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVehicleDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add Vehicle',
      ),
    );
  }
}
