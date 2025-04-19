import 'package:flutter/material.dart';

/// Show a snackbar with a message
void showSnackBar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Dismiss',
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}

// The LoadingOverlay class is now imported from widgets/loading_overlay.dart
// The ExpandableViolationCard class is now imported from widgets/expandable_violation_card.dart 