class Violation {
  final int id;
  final String vehicleNumber;
  final String violationType;
  final String location;
  final String status;
  final String imageUrl;
  final DateTime timestamp;
  final double? fine;
  final String? reportedBy;

  Violation({
    required this.id,
    required this.vehicleNumber,
    required this.violationType,
    required this.location,
    required this.status,
    required this.imageUrl,
    required this.timestamp,
    this.fine,
    this.reportedBy,
  });

  factory Violation.fromJson(Map<String, dynamic> json) {
    return Violation(
      id: json['id'],
      vehicleNumber: json['vehicle_number'],
      violationType: json['violation_type'],
      location: json['location'],
      status: json['status'],
      imageUrl: json['image_url'],
      timestamp: DateTime.parse(json['timestamp']),
      fine: json['fine'] != null ? double.parse(json['fine'].toString()) : null,
      reportedBy: json['reported_by'],
    );
  }

  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

