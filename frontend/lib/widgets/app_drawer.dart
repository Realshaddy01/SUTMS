import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/auth/login_screen.dart';

class AppDrawer extends StatelessWidget {
  final String username;
  final String userType;
  final Function(int) onScreenChange;
  final int currentIndex;
  
  const AppDrawer({
    super.key,
    required this.username,
    required this.userType,
    required this.onScreenChange,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(username),
            accountEmail: Text(userType.toUpperCase()),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (authProvider.isDriver) ...[
                  _buildDrawerItem(
                    context,
                    icon: Icons.directions_car_outlined,
                    title: 'My Vehicles',
                    index: 0,
                  ),
                ] else ...[
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    index: 0,
                  ),
                ],
                _buildDrawerItem(
                  context,
                  icon: Icons.gavel_outlined,
                  title: 'Violations',
                  index: 1,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.qr_code_scanner_outlined,
                  title: 'Scan',
                  index: 2,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Profile',
                  index: 3,
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  title: Text(
                    themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
                  ),
                  onTap: () {
                    themeProvider.setThemeMode(
                      themeProvider.isDarkMode
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  onTap: () {
                    // Navigate to help screen
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    // Show about dialog
                    showAboutDialog(
                      context: context,
                      applicationName: 'SUTMS',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.traffic, size: 48),
                      applicationLegalese: '© 2023 SUTMS',
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Smart Urban Traffic Management System is designed to improve traffic management and reduce violations through technology.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Logout'),
            onTap: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = currentIndex == index;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      selected: isSelected,
      onTap: () => onScreenChange(index),
    );
  }
}

