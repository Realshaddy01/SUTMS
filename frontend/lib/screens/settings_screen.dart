import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../models/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppConfig _appConfig;
  bool _isLoading = true;
  bool _isDarkMode = false;
  bool _isNotificationsEnabled = true;
  String _language = 'en';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final config = await AppConfig.load();
      
      // Sync with ThemeProvider
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.setThemeMode(config.isDarkModeEnabled ? ThemeMode.dark : ThemeMode.light);
      
      setState(() {
        _appConfig = config;
        _isDarkMode = config.isDarkModeEnabled;
        _isNotificationsEnabled = config.isNotificationsEnabled;
        _language = config.language;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _appConfig = AppConfig.defaultConfig;
        _isDarkMode = _appConfig.isDarkModeEnabled;
        _isNotificationsEnabled = _appConfig.isNotificationsEnabled;
        _language = _appConfig.language;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final updatedConfig = _appConfig.copyWith(
        isDarkModeEnabled: _isDarkMode,
        isNotificationsEnabled: _isNotificationsEnabled,
        language: _language,
      );
      
      await updatedConfig.save();
      
      // Update theme mode
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.setThemeMode(_isDarkMode ? ThemeMode.dark : ThemeMode.light);
      
      setState(() {
        _appConfig = updatedConfig;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _clearAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application data cleared'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'SUTMS',
        applicationVersion: _appConfig.appVersion,
        applicationIcon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.traffic,
            color: Colors.white,
          ),
        ),
        children: const [
          Text(
            'Smart Urban Traffic Management System is an innovative solution for Nepali traffic officers to report and manage traffic violations efficiently using modern technology.',
          ),
          SizedBox(height: 16),
          Text(
            '© 2023 SUTMS Team. All rights reserved.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Theme settings
                _buildSectionHeader('Appearance'),
                _buildSettingsCard([
                  ListTile(
                    title: const Text('Theme Mode'),
                    subtitle: Text(_getThemeModeDisplay()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showThemeModeSelector,
                  ),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Enable dark theme'),
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      _saveSettings();
                    },
                  ),
                  ListTile(
                    title: const Text('Language'),
                    subtitle: Text(_getLanguageDisplay(_language)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showLanguageSelector,
                  ),
                ]),
                const SizedBox(height: 16),
                
                // Notification settings
                _buildSectionHeader('Notifications'),
                _buildSettingsCard([
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text('Receive push notifications'),
                    value: _isNotificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isNotificationsEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                
                // Data settings
                _buildSectionHeader('Data'),
                _buildSettingsCard([
                  ListTile(
                    title: const Text('Clear App Data'),
                    subtitle: const Text('Delete cached data and preferences'),
                    trailing: const Icon(Icons.delete, color: Colors.red),
                    onTap: _showClearDataConfirmation,
                  ),
                ]),
                const SizedBox(height: 16),
                
                // About section
                _buildSectionHeader('About'),
                _buildSettingsCard([
                  ListTile(
                    title: const Text('Version'),
                    subtitle: Text(_appConfig.appVersion),
                  ),
                  ListTile(
                    title: const Text('About SUTMS'),
                    trailing: const Icon(Icons.info_outline),
                    onTap: _showAboutDialog,
                  ),
                  ListTile(
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to terms of service
                    },
                  ),
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to privacy policy
                    },
                  ),
                ]),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }
  
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }
  
  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          RadioListTile<String>(
            title: const Text('English'),
            value: 'en',
            groupValue: _language,
            onChanged: (value) {
              Navigator.pop(context);
              setState(() {
                _language = value!;
              });
              _saveSettings();
            },
          ),
          RadioListTile<String>(
            title: const Text('नेपाली (Nepali)'),
            value: 'ne',
            groupValue: _language,
            onChanged: (value) {
              Navigator.pop(context);
              setState(() {
                _language = value!;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }
  
  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear App Data'),
        content: const Text(
          'This will clear all cached data and preferences. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAppData();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }
  
  String _getLanguageDisplay(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ne':
        return 'नेपाली (Nepali)';
      default:
        return code;
    }
  }
  
  String _getThemeModeDisplay() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    switch (themeProvider.themeMode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System default';
    }
  }
  
  void _showThemeModeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme Mode'),
        children: [
          _buildThemeModeOption(
            'System default',
            ThemeMode.system,
            themeProvider,
          ),
          _buildThemeModeOption(
            'Light',
            ThemeMode.light,
            themeProvider,
          ),
          _buildThemeModeOption(
            'Dark',
            ThemeMode.dark,
            themeProvider,
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeModeOption(
    String title,
    ThemeMode mode,
    ThemeProvider themeProvider,
  ) {
    return SimpleDialogOption(
      onPressed: () {
        themeProvider.setThemeMode(mode);
        setState(() {
          _isDarkMode = mode == ThemeMode.dark;
        });
        _saveSettings();
        Navigator.pop(context);
      },
      child: ListTile(
        title: Text(title),
        trailing: themeProvider.themeMode == mode
            ? Icon(Icons.check, color: Theme.of(context).primaryColor)
            : null,
      ),
    );
  }
}
