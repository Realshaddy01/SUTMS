import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Function to call when notification is tapped
  final Function(NotificationModel)? onNotificationTapped;
  
  NotificationService({this.onNotificationTapped});
  
  // Initialize notification services
  Future<void> initialize() async {
    // Request permission for notifications
    await _requestPermissions();
    
    // Configure Firebase Messaging
    await _configureFirebaseMessaging();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
  }
  
  // Request permissions
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    
    print('User granted permission: ${settings.authorizationStatus}');
  }
  
  // Configure Firebase Messaging
  Future<void> _configureFirebaseMessaging() async {
    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
    
    // Configure message handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _showLocalNotification(message);
    }
  }
  
  // Handle messages opened from terminated state
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
    
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _handleNotificationTap(message);
    }
  }
  
  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }
  
  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    
    if (notification != null) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'sutms_notification_channel',
        'SUTMS Notifications',
        channelDescription: 'Notifications from Smart Urban Traffic Management System',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: json.encode(message.data),
      );
    }
  }
  
  // Handle notification tap
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final notification = _createNotificationFromData(data);
        if (onNotificationTapped != null) {
          onNotificationTapped!(notification);
        }
      } catch (e) {
        print('Error processing notification payload: $e');
      }
    }
  }
  
  // Handle notification tap from Firebase message
  void _handleNotificationTap(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      try {
        final notification = _createNotificationFromData(message.data);
        if (onNotificationTapped != null) {
          onNotificationTapped!(notification);
        }
      } catch (e) {
        print('Error processing notification data: $e');
      }
    }
  }
  
  // Create NotificationModel from data
  NotificationModel _createNotificationFromData(Map<String, dynamic> data) {
    // Convert string values to appropriate types
    int id = int.tryParse(data['notification_id'] ?? '0') ?? 0;
    int userId = int.tryParse(data['user_id'] ?? '0') ?? 0;
    int? violationId = data['violation_id'] != null ? 
        int.tryParse(data['violation_id']) : null;
    bool isRead = (data['is_read'] ?? 'false') == 'true';
    
    // Create and return notification model
    return NotificationModel(
      id: id,
      userId: userId,
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      notificationType: data['notification_type'] ?? 'general',
      relatedViolationId: violationId,
      violationDetails: data['violation_details'] != null ? 
          json.decode(data['violation_details']) : null,
      isRead: isRead,
      timestamp: data['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
  
  // Get FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
  
  // Show a local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sutms_notification_channel',
      'SUTMS Notifications',
      channelDescription: 'Notifications from Smart Urban Traffic Management System',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      0, // ID
      title,
      body,
      platformChannelSpecifics,
      payload: payload != null ? json.encode(payload) : null,
    );
  }
}

// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  // No need to create local notifications here as the system will
  // automatically show a notification in the status bar
}
