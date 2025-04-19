import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/violation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/violation.dart';

class ViolationListScreen extends StatefulWidget {
  const ViolationListScreen({Key? key}) : super(key: key);

  @override
  _ViolationListScreenState createState() => _ViolationListScreenState();
}

class _ViolationListScreenState extends State<ViolationListScreen> {
  String _currentFilter = 'all';
  final List<String> _filters = ['all', 'pending', 'paid', 'appealed'];
  
  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  Future<void> _loadViolations() async {
    await Provider.of<ViolationProvider>(context, listen: false).loadViolations();
  }

  List<Violation> _getFilteredViolations(List<Violation> violations) {
    if (_currentFilter == 'all') {
      return violations;
    }
    return violations.where((v) => v.status == _currentFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final violationProvider = Provider.of<ViolationProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;
    final isOfficer = user?.isOfficer ?? false;
    
    final filteredViolations = _getFilteredViolations(violationProvider.violations);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffic Violations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadViolations,
        child: violationProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredViolations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_currentFilter == 'all' ? '' : _currentFilter} violations found',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredViolations.length,
                    itemBuilder: (context, index) {
                      final violation = filteredViolations[index];
                      return _buildViolationCard(violation, isOfficer);
                    },
                  ),
      ),
      floatingActionButton: isOfficer
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/camera');
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildViolationCard(Violation violation, bool isOfficer) {
    // Format date
    String formattedDate;
    try {
      final date = DateTime.parse(violation.timestamp);
      formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      formattedDate = violation.timestamp;
    }
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/violation-detail',
            arguments: {'violationId': violation.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header with license plate and status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        violation.licensePlate ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(violation.status),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      violation.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Violation details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Violation type
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          violation.violationTypeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          violation.location ?? 'Unknown location',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Date
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Fine amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fine Amount',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'NPR ${violation.fineAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _viewViolationDetails(violation),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, size: 16),
                                  SizedBox(width: 4),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (violation.isPayable) ...[
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _payViolation(violation),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.payment, size: 16),
                                    SizedBox(width: 4),
                                    Text('Pay Fine'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Violations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _filters.map((filter) {
            String displayText = filter[0].toUpperCase() + filter.substring(1);
            return RadioListTile<String>(
              title: Text(displayText),
              value: filter,
              groupValue: _currentFilter,
              onChanged: (value) {
                setState(() {
                  _currentFilter = value!;
                });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'appealed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _viewViolationDetails(Violation violation) {
    Navigator.of(context).pushNamed(
      '/violation-detail',
      arguments: {'violationId': violation.id},
    );
  }
  
  void _payViolation(Violation violation) {
    Navigator.of(context).pushNamed(
      '/payment',
      arguments: {'violationId': violation.id},
    );
  }
}
