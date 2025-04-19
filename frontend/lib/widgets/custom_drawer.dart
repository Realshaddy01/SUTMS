import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CustomDrawer extends StatelessWidget {
  final String? currentRoute;
  
  const CustomDrawer({Key? key, this.currentRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isOfficer = user?.userType == 'traffic_officer';
    final isAdmin = user?.userType == 'admin';
    
    return Drawer(
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
                    Icons.person,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.fullName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Dashboard - for all users
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: currentRoute == '/home',
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/home') {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          
          // My Vehicles - for regular users
          if (user?.userType == 'vehicle_owner')
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('My Vehicles'),
              selected: currentRoute == '/vehicles',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/vehicles') {
                  Navigator.pushNamed(context, '/vehicles');
                }
              },
            ),
          
          // My Violations - for regular users
          if (user?.userType == 'vehicle_owner')
            ListTile(
              leading: const Icon(Icons.report_problem),
              title: const Text('My Violations'),
              selected: currentRoute == '/violations',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/violations') {
                  Navigator.pushNamed(context, '/violations');
                }
              },
            ),
            
          // Camera/Record Violation - for officers
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Record Violation'),
              selected: currentRoute == '/camera',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/camera') {
                  Navigator.pushNamed(context, '/camera');
                }
              },
            ),
            
          // QR Scanner - for officers
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan QR Code'),
              selected: currentRoute == '/qr_scan',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/qr_scan') {
                  Navigator.pushNamed(context, '/qr_scan');
                }
              },
            ),
            
          // Analytics - for officers
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              selected: currentRoute == '/analytics',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/analytics') {
                  Navigator.pushNamed(context, '/analytics');
                }
              },
            ),
            
          const Divider(),
          
          // Profile - for all users
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            selected: currentRoute == '/profile',
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/profile') {
                Navigator.pushNamed(context, '/profile');
              }
            },
          ),
          
          // Settings - for all users
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            selected: currentRoute == '/settings',
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/settings') {
                Navigator.pushNamed(context, '/settings');
              }
            },
          ),
          
          // Logout - for all users
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
} 