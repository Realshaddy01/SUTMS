import 'package:intl/intl.dart';

class DateFormatter {
  // Format date to 'MMM dd, yyyy'
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
  
  // Format date with time to 'MMM dd, yyyy • hh:mm a'
  static String formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }
  
  // Format relative time (e.g., '2 hours ago', 'yesterday')
  static String formatRelativeTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} ${(difference.inDays / 365).floor() == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} ${(difference.inDays / 30).floor() == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return difference.inDays == 1 ? 'yesterday' : '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      return dateString;
    }
  }
  
  // Format remaining days (e.g., '2 days left')
  static String formatRemainingDays(int days) {
    if (days <= 0) {
      return 'expired';
    } else if (days == 1) {
      return 'tomorrow';
    } else {
      return '$days days left';
    }
  }
}
