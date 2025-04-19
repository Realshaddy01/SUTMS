import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/expandable_violation_card.dart';
import '../widgets/loading_overlay.dart';
import '../utils/ui_utils.dart';

class VehicleViolationsScreen extends StatefulWidget {
  final int vehicleId;
  final String licensePlate;

  const VehicleViolationsScreen({
    Key? key,
    required this.vehicleId,
    required this.licensePlate,
  }) : super(key: key);

  @override
  _VehicleViolationsScreenState createState() => _VehicleViolationsScreenState();
}

class _VehicleViolationsScreenState extends State<VehicleViolationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _violations = [];
  
  // Date filter
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _loadViolations();
  }
  
  Future<void> _loadViolations() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Format dates for API query
      String? startDateStr;
      String? endDateStr;
      
      if (_startDate != null) {
        startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
      
      if (_endDate != null) {
        // Add one day to include the end date in results
        final nextDay = _endDate!.add(const Duration(days: 1));
        endDateStr = DateFormat('yyyy-MM-dd').format(nextDay);
      }
      
      final result = await _apiService.getVehicleViolations(
        widget.vehicleId,
        startDate: startDateStr,
        endDate: endDateStr,
      );
      
      setState(() {
        _violations = List<Map<String, dynamic>>.from(result['violations']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showSnackBar(context, 'Error loading violations: $e');
    }
  }
  
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _loadViolations();
    }
  }
  
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _loadViolations();
    }
  }
  
  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadViolations();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.licensePlate} Violations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterBottomSheet();
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _violations.isEmpty
            ? const Center(
                child: Text(
                  'No violations found',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date filter chips
                  if (_startDate != null || _endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_startDate != null)
                            Chip(
                              label: Text('From: ${DateFormat('MMM d, yyyy').format(_startDate!)}'),
                              onDeleted: () {
                                setState(() {
                                  _startDate = null;
                                });
                                _loadViolations();
                              },
                            ),
                          if (_endDate != null)
                            Chip(
                              label: Text('To: ${DateFormat('MMM d, yyyy').format(_endDate!)}'),
                              onDeleted: () {
                                setState(() {
                                  _endDate = null;
                                });
                                _loadViolations();
                              },
                            ),
                          ActionChip(
                            label: const Text('Clear All'),
                            onPressed: _clearFilters,
                          ),
                        ],
                      ),
                    ),
                  
                  // Violations list
                  for (var violation in _violations)
                    ExpandableViolationCard(violation: violation),
                ],
              ),
      ),
    );
  }
  
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Violations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Start Date'),
                subtitle: _startDate != null
                    ? Text(DateFormat('MMM d, yyyy').format(_startDate!))
                    : const Text('Not set'),
                onTap: () {
                  Navigator.pop(context);
                  _selectStartDate();
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('End Date'),
                subtitle: _endDate != null
                    ? Text(DateFormat('MMM d, yyyy').format(_endDate!))
                    : const Text('Not set'),
                onTap: () {
                  Navigator.pop(context);
                  _selectEndDate();
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearFilters();
                  },
                  child: const Text('Clear All Filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 