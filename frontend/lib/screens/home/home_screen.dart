import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../dashboard/dashboard_screen.dart';
import '../vehicles/vehicles_screen.dart';
import '../violations/violations_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  late final List<Widget> _screens;
  late final List<String> _titles;
  
  @override
  void initState() {
    super.initState();
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isDriver) {
      _screens = [
        const VehiclesScreen(),
        const ViolationsScreen(),
        const ScanScreen(),
        const ProfileScreen(),
      ];
      
      _titles = [
        'My Vehicles',
        'Violations',
        'Scan',
        'Profile',
      ];
    } else {
      _screens = [
        const DashboardScreen(),
        const ViolationsScreen(),
        const ScanScreen(),
        const ProfileScreen(),
      ];
      
      _titles = [
        'Dashboard',
        'Violations',
        'Scan',
        'Profile',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications screen
            },
          ),
        ],
      ),
      drawer: AppDrawer(
        username: user?.fullName ?? 'User',
        userType: user?.userType ?? 'User',
        onScreenChange: (index) {
          setState(() {
            _currentIndex = index;
          });
          Navigator.pop(context);
        },
        currentIndex: _currentIndex,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Provider.of<AuthProvider>(context).isDriver
                  ? Icons.directions_car_outlined
                  : Icons.dashboard_outlined,
            ),
            label: Provider.of<AuthProvider>(context).isDriver
                ? 'Vehicles'
                : 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.gavel_outlined),
            label: 'Violations',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            label: 'Scan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

