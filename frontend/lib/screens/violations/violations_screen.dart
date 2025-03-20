import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sutms/models/violation.dart';
import 'package:sutms/providers/auth_provider.dart';
import 'package:sutms/providers/violation_provider.dart';
import 'package:sutms/screens/violation_details_screen.dart';
import 'package:sutms/utils/app_theme.dart';

class ViolationsScreen extends StatefulWidget {
  const ViolationsScreen({Key? key}) : super(key: key);

  @override
  State<ViolationsScreen> createState() => _ViolationsScreenState();
}

class _ViolationsScreenState extends State<ViolationsScreen> {
  String _searchQuery = '';
  String _filterType = 'All';
  final List<String> _violationTypes = ['All', 'Speeding', 'Parking', 'Signal Jump', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchViolations();
  }

  Future<void> _fetchViolations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
    
    await violationProvider.fetchViolations(authProvider.token!);
  }

  List<Violation> _getFilteredViolations(List<Violation> violations) {
    return violations.where((violation) {
      // Apply search filter
      final matchesSearch = violation.vehicleNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          violation.location.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Apply type filter
      final matchesType = _filterType == 'All' || 
          violation.violationType.toLowerCase() == _filterType.toLowerCase();
      
      return matchesSearch && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final violationProvider = Provider.of<ViolationProvider>(context);
    final filteredViolations = _getFilteredViolations(violationProvider.violations);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Violations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by vehicle number or location',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          if (_filterType != 'All')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Filter: '),
                  Chip(
                    label: Text(_filterType),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _filterType = 'All';
                      });
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: violationProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredViolations.isEmpty
                    ? const Center(
                        child: Text(
                          'No violations found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchViolations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredViolations.length,
                          itemBuilder: (context, index) {
                            final violation = filteredViolations[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ViolationDetailsScreen(
                                        violationId: violation.id,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            violation.vehicleNumber,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          _buildStatusChip(violation.status),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.category, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            violation.violationType,
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              violation.location,
                                              style: const TextStyle(color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${violation.formattedDate} at ${violation.formattedTime}',
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      if (violation.fine != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Fine: \$${violation.fine!.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.red.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'processed':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter by Type'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _violationTypes.length,
            itemBuilder: (context, index) {
              final type = _violationTypes[index];
              return ListTile(
                title: Text(type),
                trailing: _filterType == type
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  setState(() {
                    _filterType = type;
                  });
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

