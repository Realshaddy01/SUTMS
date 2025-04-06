import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sutms_flutter/providers/auth_provider.dart';
import 'package:sutms_flutter/screens/analytics_screen.dart';
import 'package:sutms_flutter/screens/dashboard_screen.dart';
import 'package:sutms_flutter/screens/profile_screen.dart';
import 'package:sutms_flutter/screens/vehicle_screen.dart';
import 'package:sutms_flutter/screens/violations_screen.dart';
import 'package:sutms_flutter/screens/ocr_screen.dart';
import 'package:sutms_flutter/screens/qr_scanner_screen.dart';
import 'package:sutms_flutter/screens/payments_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isOfficer = user?.role == 'officer';
    final isAdmin = user?.role == 'admin';
    
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
                  user?.fullName ?? user?.username ?? 'User',
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
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
          ),
          
          // My Vehicles - for regular users
          if (!isOfficer)
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('My Vehicles'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/vehicles');
              },
            ),
          
          // My Violations - for regular users
          if (!isOfficer)
            ListTile(
              leading: const Icon(Icons.report_problem),
              title: const Text('My Violations'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/violations');
              },
            ),
            
          // Payments - for regular users
          if (!isOfficer)
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Payments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/payments');
              },
            ),
          
          // OCR Detection - for officers
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('License Plate Detection'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/ocr');
              },
            ),
            
          // QR Scanner - for officers
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan Vehicle QR'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/qr-scanner');
              },
            ),
            
          // All Violations - for officers and admins
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('All Violations'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/all-violations');
              },
            ),
            
          // Analytics - for officers and admins
          if (isOfficer || isAdmin)
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics & Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/analytics');
              },
            ),
            
          const Divider(),
          
          // Profile - for all users
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          
          // Settings - for all users
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          
          // Logout - for all users
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
