import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/violation_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/notification_provider.dart';
import '../models/user.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/recent_violations_list.dart';
import '../widgets/notification_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load notifications
    await Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
    
    // Load violations
    await Provider.of<ViolationProvider>(context, listen: false).loadViolations();
    
    // Load statistics
    await Provider.of<ViolationProvider>(context, listen: false).loadStats();
    
    // Load vehicles if user is vehicle owner
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.isVehicleOwner ?? false) {
      await Provider.of<VehicleProvider>(context, listen: false).loadVehicles();
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _navigateToCamera() {
    Navigator.of(context).pushNamed('/camera');
  }

  void _navigateToQRScanner() {
    Navigator.of(context).pushNamed('/qr-scanner');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final violationProvider = Provider.of<ViolationProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final User? user = authProvider.user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          // Notifications button with badge
          NotificationBadge(
            count: notificationProvider.unreadCount,
            onPressed: () {
              Navigator.of(context).pushNamed('/notifications');
            },
          ),
          // Settings menu
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/home'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with gradient background
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome message
                    Text(
                      'Welcome, ${user?.fullName ?? 'User'}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getWelcomeSubtitle(user),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Stats cards section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats cards
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Total violations card
                        DashboardCard(
                          title: 'Total Violations',
                          value: violationProvider.stats['total_violations']?.toString() ?? '0',
                          icon: Icons.assignment_late,
                          color: Colors.redAccent,
                          isLoading: violationProvider.isLoading,
                        ),
                        // Paid violations card
                        DashboardCard(
                          title: 'Paid Violations',
                          value: violationProvider.stats['total_paid']?.toString() ?? '0',
                          icon: Icons.payments,
                          color: Colors.greenAccent[700]!,
                          isLoading: violationProvider.isLoading,
                        ),
                        // Pending violations card
                        DashboardCard(
                          title: 'Pending Violations',
                          value: violationProvider.stats['total_pending']?.toString() ?? '0',
                          icon: Icons.pending_actions,
                          color: Colors.orangeAccent,
                          isLoading: violationProvider.isLoading,
                        ),
                        // Total fine amount card
                        DashboardCard(
                          title: 'Total Fine Amount',
                          value: 'NPR ${violationProvider.stats['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons.monetization_on,
                          color: Colors.blueAccent,
                          isLoading: violationProvider.isLoading,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Quick actions
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (user?.isOfficer ?? false) ...[
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.camera_alt,
                                      label: 'Detect Plate',
                                      color: Colors.orange,
                                      onTap: _navigateToCamera,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.qr_code_scanner,
                                      label: 'Scan QR',
                                      color: Colors.blue,
                                      onTap: _navigateToQRScanner,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.note_add,
                                      label: 'Report',
                                      color: Colors.red,
                                      onTap: () {
                                        Navigator.of(context).pushNamed('/report-violation');
                                      },
                                    ),
                                  ],
                                  if (user?.isVehicleOwner ?? false) ...[
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.directions_car,
                                      label: 'Vehicles',
                                      color: Colors.green,
                                      onTap: () {
                                        Navigator.of(context).pushNamed('/vehicles');
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.payment,
                                      label: 'Pay Fine',
                                      color: Colors.purple,
                                      onTap: () {
                                        Navigator.of(context).pushNamed('/violations');
                                      },
                                    ),
                                  ],
                                  if (user?.isAdmin ?? false) ...[
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.analytics,
                                      label: 'Analytics',
                                      color: Colors.indigo,
                                      onTap: () {
                                        Navigator.of(context).pushNamed('/analytics');
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    _buildQuickActionButton(
                                      context,
                                      icon: Icons.people,
                                      label: 'Users',
                                      color: Colors.teal,
                                      onTap: () {
                                        Navigator.of(context).pushNamed('/users');
                                      },
                                    ),
                                  ],
                                  _buildQuickActionButton(
                                    context,
                                    icon: Icons.person,
                                    label: 'Profile',
                                    color: Colors.blueGrey,
                                    onTap: () {
                                      Navigator.of(context).pushNamed('/profile');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Recent violations
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    Navigator.of(context).pushNamed('/violations');
                                  },
                                  child: const Text('View All'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (violationProvider.isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if ((violationProvider.stats['recent'] as List?)?.isEmpty ?? true)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(
                                  child: Text(
                                    'No recent violations',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              RecentViolationsList(
                                violations: violationProvider.violations,
                                onTap: (violation) {
                                  Navigator.of(context).pushNamed(
                                    '/violation-detail',
                                    arguments: {'violationId': violation.id},
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: user?.isOfficer ?? false
          ? FloatingActionButton.extended(
              onPressed: _navigateToCamera,
              label: const Text('Detect Plate'),
              icon: const Icon(Icons.camera_alt),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }
  
  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
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
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getWelcomeSubtitle(User? user) {
    if (user?.isAdmin ?? false) {
      return 'Administrator Dashboard';
    } else if (user?.isOfficer ?? false) {
      return 'Traffic Officer Dashboard';
    } else {
      return 'Vehicle Owner Dashboard';
    }
  }
}
