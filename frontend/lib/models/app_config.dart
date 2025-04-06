import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  final String apiBaseUrl;
  final String appVersion;
  final bool isDarkModeEnabled;
  final bool isNotificationsEnabled;
  final String language;

  AppConfig({
    required this.apiBaseUrl,
    required this.appVersion,
    required this.isDarkModeEnabled,
    required this.isNotificationsEnabled,
    required this.language,
  });

  // Default values
  static AppConfig get defaultConfig => AppConfig(
    apiBaseUrl: 'https://sutms-api.example.com/api',
    appVersion: '1.0.0',
    isDarkModeEnabled: false,
    isNotificationsEnabled: true,
    language: 'en',
  );

  // Load configuration from shared preferences
  static Future<AppConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return AppConfig(
        apiBaseUrl: prefs.getString('apiBaseUrl') ?? defaultConfig.apiBaseUrl,
        appVersion: prefs.getString('appVersion') ?? defaultConfig.appVersion,
        isDarkModeEnabled: prefs.getBool('isDarkModeEnabled') ?? defaultConfig.isDarkModeEnabled,
        isNotificationsEnabled: prefs.getBool('isNotificationsEnabled') ?? defaultConfig.isNotificationsEnabled,
        language: prefs.getString('language') ?? defaultConfig.language,
      );
    } catch (e) {
      print('Error loading app config: $e');
      return defaultConfig;
    }
  }

  // Save configuration to shared preferences
  Future<bool> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('apiBaseUrl', apiBaseUrl);
      await prefs.setString('appVersion', appVersion);
      await prefs.setBool('isDarkModeEnabled', isDarkModeEnabled);
      await prefs.setBool('isNotificationsEnabled', isNotificationsEnabled);
      await prefs.setString('language', language);
      
      return true;
    } catch (e) {
      print('Error saving app config: $e');
      return false;
    }
  }

  // Create a copy of AppConfig with changes
  AppConfig copyWith({
    String? apiBaseUrl,
    String? appVersion,
    bool? isDarkModeEnabled,
    bool? isNotificationsEnabled,
    String? language,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      appVersion: appVersion ?? this.appVersion,
      isDarkModeEnabled: isDarkModeEnabled ?? this.isDarkModeEnabled,
      isNotificationsEnabled: isNotificationsEnabled ?? this.isNotificationsEnabled,
      language: language ?? this.language,
    );
  }
}
