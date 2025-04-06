import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/violation.dart';
import '../providers/auth_provider.dart';
import '../providers/violation_provider.dart';
import '../widgets/violation_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ViolationScreen extends StatefulWidget {
  const ViolationScreen({Key? key}) : super(key: key);

  @override
  _ViolationScreenState createState() => _ViolationScreenState();
}

class _ViolationScreenState extends State<ViolationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  String? _violationIdToView;
  Violation? _selectedViolation;
  final TextEditingController _contestReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadViolations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contestReasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if violation ID was passed as argument
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      _violationIdToView = args;
      _loadViolationDetails();
    }
  }

  Future<void> _loadViolations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      await violationProvider.fetchViolations(
        authProvider.user!.token, 
        authProvider.userType
      );
      
      await violationProvider.fetchViolationTypes(authProvider.user!.token);
    } catch (e) {
      setState(() {
        _error = 'Failed to load violations. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadViolationDetails() async {
    if (_violationIdToView == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      _selectedViolation = await violationProvider.getViolationById(
        authProvider.user!.token,
        _violationIdToView!,
      );
      
      if (_selectedViolation != null) {
        _showViolationDetailsDialog(_selectedViolation!);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load violation details. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _violationIdToView = null;  // Reset after loading
        });
      }
    }
  }

  void _showViolationDetailsDialog(Violation violation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Violation Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (violation.evidenceImageUrl != null) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      violation.evidenceImageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
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
                        return Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Violation Type
              ListTile(
                title: const Text('Violation Type'),
                subtitle: Text(
                  violation.violationTypeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: const Icon(Icons.warning, color: Colors.red),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Status
              ListTile(
                title: const Text('Status'),
                subtitle: Text(
                  violation.statusDisplayText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(violation.status),
                  ),
                ),
                leading: const Icon(Icons.info_outline),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Payment Status
              if (violation.paymentStatus != null)
                ListTile(
                  title: const Text('Payment Status'),
                  subtitle: Text(
                    violation.paymentStatusDisplayText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getPaymentStatusColor(violation.paymentStatus!),
                    ),
                  ),
                  leading: const Icon(Icons.payment),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              
              // Vehicle
              ListTile(
                title: const Text('Vehicle'),
                subtitle: Text(
                  violation.vehicleLicensePlate,
                  style: const TextStyle(fontSize: 16),
                ),
                leading: const Icon(Icons.directions_car),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Date & Time
              ListTile(
                title: const Text('Date & Time'),
                subtitle: Text(
                  violation.formattedDate,
                  style: const TextStyle(fontSize: 16),
                ),
                leading: const Icon(Icons.calendar_today),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Location
              ListTile(
                title: const Text('Location'),
                subtitle: Text(
                  violation.location,
                  style: const TextStyle(fontSize: 16),
                ),
                leading: const Icon(Icons.location_on),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Description
              if (violation.description != null && violation.description!.isNotEmpty)
                ListTile(
                  title: const Text('Description'),
                  subtitle: Text(
                    violation.description!,
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: const Icon(Icons.description),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              
              // License Plate Detection
              if (violation.detectedLicensePlate != null)
                ListTile(
                  title: const Text('Detected License Plate'),
                  subtitle: Text(
                    '${violation.detectedLicensePlate!} (Confidence: ${(violation.confidenceScore! * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: const Icon(Icons.document_scanner),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          if (violation.canPay)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(
                  context,
                  '/payment',
                  arguments: violation.id,
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Pay Fine'),
            ),
          if (violation.canContest)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showContestDialog(violation);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Contest'),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'contested': return Colors.purple;
      case 'resolved': return Colors.green;
      case 'cancelled': return Colors.grey;
      default: return Colors.black;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      case 'refunded': return Colors.blue;
      default: return Colors.black;
    }
  }

  void _showContestDialog(Violation violation) {
    _contestReasonController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contest Violation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Violation: ${violation.violationTypeName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Vehicle: ${violation.vehicleLicensePlate}'),
            Text('Date: ${violation.formattedDate}'),
            const SizedBox(height: 16),
            const Text(
              'Please provide a reason for contesting this violation:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _contestReasonController,
              labelText: 'Reason',
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide a reason';
                }
                return null;
              },
            ),
          ],
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
              if (_contestReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for contesting')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              await _contestViolation(violation.id, _contestReasonController.text.trim());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Submit Contest'),
          ),
        ],
      ),
    );
  }

  Future<void> _contestViolation(String violationId, String reason) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      final success = await violationProvider.contestViolation(
        authProvider.user!.token,
        violationId,
        reason,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Violation contested successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(violationProvider.error ?? 'Failed to contest violation')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to contest violation. Please try again.';
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
    final violationProvider = Provider.of<ViolationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final List<Violation> allViolations = violationProvider.violations;
    final List<Violation> pendingViolations = allViolations.where((v) => v.isPending).toList();
    final List<Violation> activeViolations = allViolations.where((v) => v.isConfirmed || v.isContested).toList();
    final List<Violation> resolvedViolations = allViolations.where((v) => v.isResolved || v.isCancelled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Violations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading violations...')
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
                        onPressed: _loadViolations,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // All Violations Tab
                    _buildViolationList(allViolations),
                    
                    // Pending Violations Tab
                    _buildViolationList(
                      pendingViolations,
                      emptyMessage: 'No pending violations',
                    ),
                    
                    // Active Violations Tab
                    _buildViolationList(
                      activeViolations,
                      emptyMessage: 'No active violations',
                    ),
                    
                    // Resolved Violations Tab
                    _buildViolationList(
                      resolvedViolations,
                      emptyMessage: 'No resolved violations',
                    ),
                  ],
                ),
      // Add a floating action button for traffic officers to record new violations
      floatingActionButton: authProvider.userType == 'traffic_officer'
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camera');
              },
              child: const Icon(Icons.camera_alt),
              tooltip: 'Record Violation',
            )
          : null,
    );
  }

  Widget _buildViolationList(List<Violation> violations, {String? emptyMessage}) {
    return violations.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage ?? 'No violations',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadViolations,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: violations.length,
              itemBuilder: (context, index) {
                final violation = violations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ViolationCard(
                    violation: violation,
                    onTap: () => _showViolationDetailsDialog(violation),
                    onPayPressed: violation.canPay
                        ? () {
                            Navigator.pushNamed(
                              context,
                              '/payment',
                              arguments: violation.id,
                            );
                          }
                        : null,
                  ),
                );
              },
            ),
          );
  }
}
