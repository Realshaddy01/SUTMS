import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sutms/providers/auth_provider.dart';
import 'package:sutms/providers/violation_provider.dart';
import 'package:sutms/screens/profile_screen.dart';
import 'package:sutms/screens/camera_screen.dart';
import 'package:sutms/screens/video_processing_screen.dart';
import 'package:sutms/screens/violations_screen.dart';
import 'package:sutms/utils/app_theme.dart';
import 'package:sutms/widgets/dashboard_card.dart';
import 'package:sutms/widgets/main_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final violationProvider = Provider.of<ViolationProvider>(context, listen: false);

    try {
      await violationProvider.fetchViolations(authProvider.token!);
    } catch (e) {
      // Handle error
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
    final user = authProvider.user;
    final isOfficer = user?.isStaff ?? false;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Show notifications
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  user?.username.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: const MainDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.fullName ?? 'User'}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOfficer
                          ? 'Monitor and manage traffic violations'
                          : 'Track your vehicles and violations',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        if (isOfficer) ...[
                          DashboardCard(
                            title: 'Capture Violation',
                            icon: Icons.camera_alt,
                            color: AppTheme.primaryColor,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CameraScreen(),
                                ),
                              );
                            },
                          ),
                          DashboardCard(
                            title: 'Process CCTV',
                            icon: Icons.videocam,
                            color: Colors.purple,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const VideoProcessingScreen(),
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          DashboardCard(
                            title: 'My Vehicles',
                            icon: Icons.directions_car,
                            color: AppTheme.primaryColor,
                            onTap: () {
                              // Navigate to vehicles screen
                            },
                          ),
                          DashboardCard(
                            title: 'Pay Fines',
                            icon: Icons.payment,
                            color: Colors.green,
                            onTap: () {
                              // Navigate to payment screen
                            },
                          ),
                        ],
                        DashboardCard(
                          title: 'View Violations',
                          icon: Icons.list_alt,
                          color: Colors.orange,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ViolationsScreen(),
                              ),
                            );
                          },
                        ),
                        DashboardCard(
                          title: 'My Profile',
                          icon: Icons.person,
                          color: Colors.teal,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recent Violations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    violationProvider.violations.isEmpty
                        ? const Center(
                            child: Text(
                              'No violations reported yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: violationProvider.violations.length > 5
                                ? 5
                                : violationProvider.violations.length,
                            itemBuilder: (context, index) {
                              final violation = violationProvider.violations[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getViolationColor(violation.violationType),
                                    child: const Icon(Icons.car_crash, color: Colors.white),
                                  ),
                                  title: Text(violation.vehicleLicensePlate),
                                  subtitle: Text(
                                    '${violation.violationTypeName} at ${violation.location}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    violation.formattedDate,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  onTap: () {
                                    // Navigate to violation details
                                  },
                                ),
                              );
                            },
                          ),
                    if (violationProvider.violations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ViolationsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View All Violations'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      floatingActionButton: isOfficer
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CameraScreen(),
                  ),
                );
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.camera_alt),
            )
          : null,
    );
  }

  Color _getViolationColor(String violationType) {
    switch (violationType.toLowerCase()) {
      case 'speeding':
        return Colors.red;
      case 'parking':
        return Colors.orange;
      case 'signal jump':
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
  }
}

