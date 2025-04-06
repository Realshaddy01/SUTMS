class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String notificationType;
  final int? relatedViolationId;
  final Map<String, dynamic>? violationDetails;
  final bool isRead;
  final String timestamp;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.relatedViolationId,
    this.violationDetails,
    required this.isRead,
    required this.timestamp,
  });

  // Factory constructor to create a Notification from JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user'],
      title: json['title'],
      message: json['message'],
      notificationType: json['notification_type'],
      relatedViolationId: json['related_violation'],
      violationDetails: json['violation_details'],
      isRead: json['is_read'],
      timestamp: json['timestamp'],
    );
  }

  // Convert Notification to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'related_violation': relatedViolationId,
      'violation_details': violationDetails,
      'is_read': isRead,
      'timestamp': timestamp,
    };
  }

  // Create a copy of NotificationModel with changes
  NotificationModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? message,
    String? notificationType,
    int? relatedViolationId,
    Map<String, dynamic>? violationDetails,
    bool? isRead,
    String? timestamp,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      relatedViolationId: relatedViolationId ?? this.relatedViolationId,
      violationDetails: violationDetails ?? this.violationDetails,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
