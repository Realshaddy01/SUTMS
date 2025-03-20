class ViolationType {
  final int id;
  final String name;
  final String description;
  final double fineAmount;
  final int penaltyPoints;

  ViolationType({
    required this.id,
    required this.name,
    required this.description,
    required this.fineAmount,
    required this.penaltyPoints,
  });

  factory ViolationType.fromJson(Map<String, dynamic> json) {
    return ViolationType(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      fineAmount: double.parse(json['fine_amount'].toString()),
      penaltyPoints: json['penalty_points'],
    );
  }
}

class Violation {
  final int id;
  final int vehicleId;
  final int violationTypeId;
  final int reportedById;
  final String location;
  final double? latitude;
  final double? longitude;
  final String timestamp;
  final String description;
  final String? evidenceImage;
  final String status;
  final double fineAmount;
  final bool isPaid;
  final String? paymentDate;
  final Map<String, dynamic>? vehicleDetails;
  final Map<String, dynamic>? violationTypeDetails;
  final String? reporterName;

  Violation({
    required this.id,
    required this.vehicleId,
    required this.violationTypeId,
    required this.reportedById,
    required this.location,
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.description,
    this.evidenceImage,
    required this.status,
    required this.fineAmount,
    required this.isPaid,
    this.paymentDate,
    this.vehicleDetails,
    this.violationTypeDetails,
    this.reporterName,
  });

  factory Violation.fromJson(Map<String, dynamic> json) {
    return Violation(
      id: json['id'],
      vehicleId: json['vehicle'],
      violationTypeId: json['violation_type'],
      reportedById: json['reported_by'],
      location: json['location'],
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      timestamp: json['timestamp'],
      description: json['description'],
      evidenceImage: json['evidence_image'],
      status: json['status'],
      fineAmount: double.parse(json['fine_amount'].toString()),
      isPaid: json['is_paid'],
      paymentDate: json['payment_date'],
      vehicleDetails: json['vehicle_details'],
      violationTypeDetails: json['violation_type_details'],
      reporterName: json['reporter_name'],
    );
  }

  String get violationTypeName => 
      violationTypeDetails != null ? violationTypeDetails!['name'] : 'Unknown';
      
  String get vehicleLicensePlate => 
      vehicleDetails != null ? vehicleDetails!['license_plate'] : 'Unknown';
      
  String get formattedDate {
    final date = DateTime.parse(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedTime {
    final date = DateTime.parse(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class ViolationAppeal {
  final int id;
  final int violationId;
  final int submittedById;
  final String reason;
  final String? evidenceImage;
  final String submittedAt;
  final String status;
  final int? reviewedById;
  final String? reviewedAt;
  final String? reviewerComments;
  final String? submitterName;
  final String? reviewerName;

  ViolationAppeal({
    required this.id,
    required this.violationId,
    required this.submittedById,
    required this.reason,
    this.evidenceImage,
    required this.submittedAt,
    required this.status,
    this.reviewedById,
    this.reviewedAt,
    this.reviewerComments,
    this.submitterName,
    this.reviewerName,
  });

  factory ViolationAppeal.fromJson(Map<String, dynamic> json) {
    return ViolationAppeal(
      id: json['id'],
      violationId: json['violation'],
      submittedById: json['submitted_by'],
      reason: json['reason'],
      evidenceImage: json['evidence_image'],
      submittedAt: json['submitted_at'],
      status: json['status'],
      reviewedById: json['reviewed_by'],
      reviewedAt: json['reviewed_at'],
      reviewerComments: json['reviewer_comments'],
      submitterName: json['submitter_name'],
      reviewerName: json['reviewer_name'],
    );
  }
}

