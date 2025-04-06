import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/map_screen.dart';
import '../screens/detection_screen.dart';
import '../screens/violations_screen.dart';
import '../screens/profile_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService.instance;
    final String? userRole = apiService.userRole;

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
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  apiService.username ?? 'Guest User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Text(
                  _getRoleDisplay(userRole),
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
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Traffic Map'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/map');
            },
          ),
          if (userRole == Constants.roleOfficer || userRole == Constants.roleAdmin)
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('License Plate Detection'),
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/detection');
              },
            ),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Traffic Violations'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/violations');
            },
          ),
          if (userRole == Constants.roleAdmin)
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/analytics');
              },
            ),
          if (userRole == Constants.roleUser)
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('My Vehicles'),
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/vehicles');
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await apiService.logout();
              // Ignore navigation if widget is unmounted
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }
  
  String _getRoleDisplay(String? role) {
    switch (role) {
      case Constants.roleAdmin:
        return 'Administrator';
      case Constants.roleOfficer:
        return 'Traffic Officer';
      case Constants.roleUser:
        return 'Vehicle Owner';
      default:
        return 'Guest User';
    }
  }
}
