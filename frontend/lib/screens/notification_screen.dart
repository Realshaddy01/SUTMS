import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/violation.dart';
import '../providers/auth_provider.dart';
import '../providers/violation_provider.dart';
import '../widgets/loading_indicator.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }
  
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      await violationProvider.fetchNotifications(authProvider.user!.token);
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _markAllAsRead() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      final success = await violationProvider.markAllNotificationsAsRead(authProvider.user!.token);
      
      if (!success) {
        setState(() {
          _error = violationProvider.error ?? 'Failed to mark notifications as read';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to mark notifications as read. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _markAsRead(Notification notification) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      await violationProvider.markNotificationAsRead(
        authProvider.user!.token,
        notification.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notification as read: ${e.toString()}')),
        );
      }
    }
  }
  
  void _viewViolationDetails(String violationId) {
    Navigator.pushNamed(
      context,
      '/violations',
      arguments: violationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final violationProvider = Provider.of<ViolationProvider>(context);
    final notifications = violationProvider.notifications;
    final hasUnread = notifications.any((n) => !n.isRead);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading notifications...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return Dismissible(
                            key: Key(notification.id),
                            direction: DismissDirection.horizontal,
                            onDismissed: (_) {
                              // Mark as read when dismissed
                              _markAsRead(notification);
                            },
                            background: Container(
                              color: Colors.green,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(
                                Icons.done,
                                color: Colors.white,
                              ),
                            ),
                            secondaryBackground: Container(
                              color: Colors.green,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(
                                Icons.done,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: notification.isRead
                                    ? Colors.grey.shade200
                                    : Colors.blue.shade100,
                                child: Icon(
                                  _getNotificationIcon(notification.title),
                                  color: notification.isRead
                                      ? Colors.grey
                                      : Colors.blue,
                                ),
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.message),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              tileColor: notification.isRead ? null : Colors.blue.shade50,
                              onTap: () {
                                _markAsRead(notification);
                                
                                if (notification.violationId != null) {
                                  _viewViolationDetails(notification.violationId!);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
  
  IconData _getNotificationIcon(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('violation')) return Icons.warning;
    if (lowerTitle.contains('payment')) return Icons.payment;
    if (lowerTitle.contains('contested')) return Icons.gavel;
    if (lowerTitle.contains('confirmed')) return Icons.check_circle;
    if (lowerTitle.contains('resolved')) return Icons.done_all;
    
    return Icons.notifications;
  }
}
