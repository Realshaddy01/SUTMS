import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  
  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  
  // Service
  final _apiService = ApiService();
  
  // Load all notifications for current user
  Future<void> loadNotifications() async {
    if (_isLoading) return; // Prevent multiple simultaneous loads
    
    _isLoading = true;
    // Only notify if we're not in the middle of a build
    try {
      final data = await _apiService.getNotifications();
      _notifications = data;
      _error = null;
      // Update unread count without notifying
      final count = await _apiService.getUnreadNotificationCount();
      _unreadCount = count;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify only once at the end
    }
  }
  
  // Get unread notification count
  Future<void> getUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationCount();
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      print('Error getting unread count: $e');
    }
  }
  
  // Mark notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      final success = await _apiService.markNotificationAsRead(notificationId);
      if (success) {
        final index = _notifications.indexWhere((item) => item.id == notificationId);
        if (index >= 0) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          if (_unreadCount > 0) _unreadCount--;
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    if (_isLoading) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final success = await _apiService.markAllNotificationsAsRead();
      if (success) {
        _notifications = _notifications.map((notification) => 
          notification.copyWith(isRead: true)
        ).toList();
        _unreadCount = 0;
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Add a new notification (when received from Firebase)
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead) _unreadCount++;
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
