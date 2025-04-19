import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/loading_indicator.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({Key? key}) : super(key: key);

  @override
  _AddVehicleScreenState createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  
  // Form fields
  final _licensePlateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _billBookNumberController = TextEditingController();
  final _vinController = TextEditingController();
  
  DateTime? _registrationExpiry;
  int _selectedVehicleType = 1; // Default to car
  
  final List<Map<String, dynamic>> _vehicleTypes = [
    {'id': 1, 'name': 'Car'},
    {'id': 2, 'name': 'Motorcycle'},
    {'id': 3, 'name': 'Truck'},
    {'id': 4, 'name': 'Bus'},
  ];

  @override
  void dispose() {
    _licensePlateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _registrationNumberController.dispose();
    _billBookNumberController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _registrationExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    
    if (picked != null && picked != _registrationExpiry) {
      setState(() {
        _registrationExpiry = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
      
      if (authProvider.user == null || authProvider.user!.token == null) {
        throw Exception('You need to be logged in to add a vehicle');
      }
      
      final success = await vehicleProvider.addVehicle(
        authProvider.user!.token!,
        ownerId: authProvider.user!.id,
        licensePlate: _licensePlateController.text,
        make: _makeController.text,
        model: _modelController.text,
        year: int.parse(_yearController.text),
        color: _colorController.text,
        registrationNumber: _registrationNumberController.text,
        vehicleTypeId: _selectedVehicleType,
        billBookNumber: _billBookNumberController.text,
        vin: _vinController.text,
        registrationExpiry: _registrationExpiry,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle added successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _error = vehicleProvider.error ?? 'Failed to add vehicle';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Vehicle'),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Adding vehicle...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                      
                    // Vehicle Type
                    const Text(
                      'Vehicle Type',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedVehicleType,
                          items: _vehicleTypes.map((type) {
                            return DropdownMenuItem<int>(
                              value: type['id'],
                              child: Text(type['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedVehicleType = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // License Plate
                    TextFormField(
                      controller: _licensePlateController,
                      decoration: const InputDecoration(
                        labelText: 'License Plate Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.car_rental),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter license plate number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Make and Model (Row)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _makeController,
                            decoration: const InputDecoration(
                              labelText: 'Make',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _modelController,
                            decoration: const InputDecoration(
                              labelText: 'Model',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Year and Color (Row)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yearController,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Invalid year';
                              }
                              final year = int.parse(value);
                              if (year < 1900 || year > DateTime.now().year + 1) {
                                return 'Invalid year';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _colorController,
                            decoration: const InputDecoration(
                              labelText: 'Color',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Registration Number
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        border: OutlineInputBorder(),
                        helperText: 'Number from your vehicle registration document',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter registration number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Registration Expiry Date
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Registration Expiry Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: _registrationExpiry != null
                                ? DateFormat('yyyy-MM-dd').format(_registrationExpiry!)
                                : '',
                          ),
                          validator: (value) {
                            if (_registrationExpiry == null) {
                              return 'Please select expiry date';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Bill Book Number
                    TextFormField(
                      controller: _billBookNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Bill Book Number',
                        border: OutlineInputBorder(),
                        helperText: 'Optional - Number from your vehicle bill book',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // VIN (Vehicle Identification Number)
                    TextFormField(
                      controller: _vinController,
                      decoration: const InputDecoration(
                        labelText: 'VIN (Chassis Number)',
                        border: OutlineInputBorder(),
                        helperText: 'Optional - Vehicle Identification Number',
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        child: const Text('ADD VEHICLE', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 