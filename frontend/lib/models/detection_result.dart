import 'dart:io';
import 'package:sutms/providers/detection_provider.dart';

class DetectionResult {
  final int id;
  final String numberPlate;
  final DetectionType detectionType;
  final double confidence;
  final DateTime timestamp;
  final File? imageFile;
  final Duration? videoTimestamp;

  DetectionResult({
    required this.id,
    required this.numberPlate,
    required this.detectionType,
    required this.confidence,
    required this.timestamp,
    this.imageFile,
    this.videoTimestamp,
  });

  String get violationTypeString {
    switch (detectionType) {
      case DetectionType.numberPlate:
        return 'Number Plate Detection';
      case DetectionType.speedViolation:
        return 'Speed Violation';
      case DetectionType.signalViolation:
        return 'Signal Jump';
      case DetectionType.parkingViolation:
        return 'Illegal Parking';
      case DetectionType.overCapacity:
        return 'Over Capacity';
      case DetectionType.foreignVehicle:
        return 'Unauthorized Foreign Vehicle';
    }
  }

  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}';
  }

  String get formattedVideoTimestamp {
    if (videoTimestamp == null) return '';
    
    final minutes = videoTimestamp!.inMinutes;
    final seconds = videoTimestamp!.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

