import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/violation_provider.dart';
import '../models/violation.dart';

class ViolationDetailScreen extends StatefulWidget {
  final int violationId;

  const ViolationDetailScreen({
    Key? key,
    required this.violationId,
  }) : super(key: key);

  @override
  _ViolationDetailScreenState createState() => _ViolationDetailScreenState();
}

class _ViolationDetailScreenState extends State<ViolationDetailScreen> {
  late Future<Violation?> _violationFuture;

  @override
  void initState() {
    super.initState();
    _loadViolationDetails();
  }

  Future<void> _loadViolationDetails() async {
    setState(() {
      _violationFuture = Provider.of<ViolationProvider>(context, listen: false)
          .getViolationDetails(widget.violationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Violation Details'),
      ),
      body: FutureBuilder<Violation?>(
        future: _violationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadViolationDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('No violation details found'),
            );
          }
          
          final violation = snapshot.data!;
          return _buildViolationDetails(violation);
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<ViolationProvider>(
            builder: (context, provider, child) {
              final violation = provider.selectedViolation;
              if (violation == null) return const SizedBox.shrink();
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (violation.isPayable)
                    FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/payment',
                          arguments: {'violationId': violation.id},
                        );
                      },
                      heroTag: 'pay',
                      icon: const Icon(Icons.payment),
                      label: const Text('Pay Fine'),
                      backgroundColor: Colors.green,
                    ),
                  if (violation.isPayable && violation.isAppealable)
                    const SizedBox(height: 8),
                  if (violation.isAppealable)
                    FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/appeal',
                          arguments: {'violationId': violation.id},
                        );
                      },
                      heroTag: 'appeal',
                      icon: const Icon(Icons.gavel),
                      label: const Text('Appeal'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViolationDetails(Violation violation) {
    // Format date
    String formattedDate;
    try {
      final date = DateTime.parse(violation.timestamp);
      formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      formattedDate = violation.timestamp;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getStatusColor(violation.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      _getStatusIcon(violation.status),
                      color: _getStatusColor(violation.status),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          violation.statusDisplay ?? violation.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _getStatusColor(violation.status),
                          ),
                        ),
                        if (violation.finePaid != null && !violation.finePaid! && violation.daysUntilDeadline != null && violation.daysUntilDeadline! > 0)
                          Text(
                            'Due in ${violation.daysUntilDeadline} days',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                        if (violation.finePaid != null && violation.finePaid! && violation.paymentDate != null)
                          Text(
                            'Paid on ${_formatDate(violation.paymentDate!)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'NPR ${violation.fineAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Fine Amount',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Violation details card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Violation Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow('Violation Type', violation.violationTypeName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Date & Time', formattedDate),
                  const SizedBox(height: 12),
                  _buildDetailRow('Location', violation.location ?? 'Unknown'),
                  if (violation.description != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('Description', violation.description!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Vehicle details card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow('License Plate', violation.licensePlate ?? 'Unknown'),
                  if (violation.vehicleDetails != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Vehicle Info',
                      '${violation.vehicleDetails!['make'] ?? 'N/A'} ${violation.vehicleDetails!['model'] ?? ''}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Color',
                      violation.vehicleDetails!['color'] ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Owner',
                      violation.vehicleDetails!['owner_name'] ?? 'N/A',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Evidence card
          if (violation.evidenceImage != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evidence',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Divider(),
                      ],
                    ),
                  ),
                  if (violation.evidenceImage != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        violation.evidenceImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Text('Failed to load image'),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          
          // Appeal details card
          if (violation.appealText != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appeal Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDetailRow('Appeal Date', _formatDate(violation.appealDate)),
                    const SizedBox(height: 12),
                    _buildDetailRow('Appeal Status', violation.appealStatus ?? 'Pending'),
                    const SizedBox(height: 12),
                    const Text(
                      'Appeal Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(violation.appealText!),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(value ?? 'Unknown'),
        ),
      ],
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown';
    }
    return DateFormat('MMM dd, yyyy').format(dateTime);
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'paid':
        return Icons.check_circle;
      case 'appealed':
        return Icons.gavel;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
