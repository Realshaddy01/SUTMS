import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/violation_provider.dart';
import '../widgets/violation_card.dart';
import '../widgets/loading_indicator.dart';
import '../utils/constants.dart';

class OfficerScreen extends StatefulWidget {
  const OfficerScreen({Key? key}) : super(key: key);

  @override
  _OfficerScreenState createState() => _OfficerScreenState();
}

class _OfficerScreenState extends State<OfficerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      await Future.wait([
        violationProvider.fetchViolations(authProvider.user!.token, authProvider.userType),
        violationProvider.fetchViolationTypes(authProvider.user!.token),
        violationProvider.fetchNotifications(authProvider.user!.token),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to load data. Please try again.';
      });
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
    final authProvider = Provider.of<AuthProvider>(context);
    final violationProvider = Provider.of<ViolationProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              if (violationProvider.unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${violationProvider.unreadNotificationsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Violations'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.security,
                      size: 30,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    authProvider.user?.fullName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Badge: ${authProvider.user?.badgeNumber ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _tabController.index == 0,
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem),
              title: const Text('Violations'),
              selected: _tabController.index == 1,
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              selected: _tabController.index == 2,
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('Scan QR Code'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/qr_scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Record Violation'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/camera');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading dashboard...')
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
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Dashboard Tab
                    _buildDashboardTab(),
                    
                    // Violations Tab
                    _buildViolationsTab(),
                    
                    // Analytics Tab
                    _buildAnalyticsTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/camera');
        },
        child: const Icon(Icons.camera_alt),
        tooltip: 'Record Violation',
      ),
    );
  }

  Widget _buildDashboardTab() {
    final violationProvider = Provider.of<ViolationProvider>(context);
    final violations = violationProvider.violations;
    
    // Get counts for different violation statuses
    final pendingCount = violations.where((v) => v.isPending).length;
    final confirmedCount = violations.where((v) => v.isConfirmed).length;
    final contestedCount = violations.where((v) => v.isContested).length;
    final resolvedCount = violations.where((v) => v.isResolved).length;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Violations Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          context,
                          Icons.hourglass_empty,
                          'Pending',
                          pendingCount.toString(),
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          context,
                          Icons.check_circle,
                          'Confirmed',
                          confirmedCount.toString(),
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          context,
                          Icons.pan_tool,
                          'Contested',
                          contestedCount.toString(),
                          color: Colors.purple,
                        ),
                        _buildStatCard(
                          context,
                          Icons.done_all,
                          'Resolved',
                          resolvedCount.toString(),
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Record Violation',
                    Icons.camera_alt,
                    Colors.red,
                    () {
                      Navigator.pushNamed(context, '/camera');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Scan QR Code',
                    Icons.qr_code_scanner,
                    Colors.blue,
                    () {
                      Navigator.pushNamed(context, '/qr_scan');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    'View Analytics',
                    Icons.analytics,
                    Colors.green,
                    () {
                      _tabController.animateTo(2);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    context,
                    'View All Violations',
                    Icons.list_alt,
                    Colors.orange,
                    () {
                      _tabController.animateTo(1);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Recent Violations
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Violations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (violations.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('No violations recorded yet'),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: violations.length > 5 ? 5 : violations.length,
                itemBuilder: (context, index) {
                  final violation = violations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ViolationCard(
                      violation: violation,
                      onTap: () {
                        _showViolationDetailsDialog(violation);
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationsTab() {
    final violationProvider = Provider.of<ViolationProvider>(context);
    final violations = violationProvider.violations;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: violations.isEmpty
          ? const Center(
              child: Text('No violations recorded yet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: violations.length,
              itemBuilder: (context, index) {
                final violation = violations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ViolationCard(
                    violation: violation,
                    onTap: () {
                      _showViolationDetailsDialog(violation);
                    },
                    showActions: true,
                    onUpdateStatus: (newStatus) {
                      _updateViolationStatus(violation.id, newStatus);
                    },
                    onDetectLicensePlate: () {
                      _detectLicensePlate(violation.id);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const AnalyticsScreen(),
          settings: settings,
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showViolationDetailsDialog(dynamic violation) {
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
          if (violation.isPending)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateViolationStatus(violation.id, 'confirmed');
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Confirm'),
            ),
          if (violation.isPending)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateViolationStatus(violation.id, 'cancelled');
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel'),
            ),
          if (violation.evidenceImageUrl != null && (violation.detectedLicensePlate == null || violation.detectedLicensePlate!.isEmpty))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _detectLicensePlate(violation.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('Detect Plate'),
            ),
        ],
      ),
    );
  }

  Future<void> _updateViolationStatus(String violationId, String newStatus) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      final success = await violationProvider.updateViolationStatus(
        authProvider.user!.token,
        violationId,
        newStatus,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Violation status updated to ${newStatus.toUpperCase()}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(violationProvider.error ?? 'Failed to update violation status')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update violation status. Please try again.';
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

  Future<void> _detectLicensePlate(String violationId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      final result = await violationProvider.detectLicensePlate(
        authProvider.user!.token,
        violationId,
      );
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('License plate detected: ${result['detected_license_plate']} (Confidence: ${(result['confidence_score'] * 100).toStringAsFixed(1)}%)')),
        );
        
        // Refresh data to show updated license plate
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(violationProvider.error ?? 'Failed to detect license plate')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to detect license plate. Please try again.';
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
}
