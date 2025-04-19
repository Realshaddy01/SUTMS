import 'user.dart';
import 'vehicle.dart';
import 'violation_type.dart';
import 'package:intl/intl.dart';

class Violation {
  final int id;
  final String violationType;
  final String? description;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String timestamp;
  final double fineAmount;
  final String status;
  final String? evidenceUrl;
  final int vehicleId;
  final int officerId;
  final String createdAt;
  final Vehicle? vehicle;
  final User? officer;
  final Map<String, dynamic>? payment;
  final String? licensePlate;
  final ViolationType? violationTypeObj;
  final String? evidenceImage;
  final String? detectedLicensePlate;
  final double? confidenceScore;
  final bool? finePaid;
  final DateTime? paymentDate;
  final String? appealText;
  final DateTime? appealDate;
  final String? appealStatus;
  final int? daysUntilDeadline;
  final Map<String, dynamic>? vehicleDetails;
  
  Violation({
    required this.id,
    required this.violationType,
    this.description,
    this.location,
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.fineAmount,
    required this.status,
    this.evidenceUrl,
    required this.vehicleId,
    required this.officerId,
    required this.createdAt,
    this.vehicle,
    this.officer,
    this.payment,
    this.licensePlate,
    this.violationTypeObj,
    this.evidenceImage,
    this.detectedLicensePlate,
    this.confidenceScore,
    this.finePaid,
    this.paymentDate,
    this.appealText,
    this.appealDate,
    this.appealStatus,
    this.daysUntilDeadline,
    this.vehicleDetails,
  });
  
  String get violationTypeName => violationTypeObj?.name ?? violationType;
  String get vehicleLicensePlate => licensePlate ?? vehicle?.licensePlate ?? 'Unknown';
  String get statusDisplay => getStatusDisplay(status);
  String get statusDisplayText => getStatusDisplay(status);
  String get paymentStatus => payment != null ? (payment!['status'] ?? 'UNPAID') : 'UNPAID';
  String get paymentStatusDisplayText => getPaymentStatusDisplay(paymentStatus);
  DateTime get createdAtDate => DateTime.parse(createdAt);
  String get formattedDate => DateFormat('MMM d, yyyy').format(createdAtDate);
  
  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isContested => status == 'CONTESTED';
  bool get isResolved => status == 'RESOLVED';
  bool get isCancelled => status == 'CANCELLED';
  
  bool get isPayable => !finePaid! && (status == 'CONFIRMED' || status == 'PENDING');
  bool get isAppealable => status == 'CONFIRMED' && (appealStatus == null || appealStatus == 'REJECTED');
  bool get canPay => isPayable;
  bool get canContest => isAppealable;
  
  String getStatusDisplay(String status) {
    switch (status) {
      case 'PENDING': return 'Pending';
      case 'CONFIRMED': return 'Confirmed';
      case 'CONTESTED': return 'Contested';
      case 'RESOLVED': return 'Resolved';
      case 'CANCELLED': return 'Cancelled';
      default: return status;
    }
  }
  
  String getPaymentStatusDisplay(String status) {
    switch (status) {
      case 'PAID': return 'Paid';
      case 'PROCESSING': return 'Processing';
      case 'PENDING': return 'Pending';
      case 'UNPAID': return 'Unpaid';
      default: return status;
    }
  }
  
  factory Violation.fromJson(Map<String, dynamic> json) {
    return Violation(
      id: json['id'],
      violationType: json['violation_type'],
      description: json['description'],
      location: json['location'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      timestamp: json['timestamp'],
      fineAmount: json['fine_amount'].toDouble(),
      status: json['status'],
      evidenceUrl: json['evidence_url'],
      vehicleId: json['vehicle_id'],
      officerId: json['officer_id'],
      createdAt: json['created_at'],
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      officer: json['officer'] != null ? User.fromJson(json['officer']) : null,
      payment: json['payment'],
      licensePlate: json['license_plate'],
      violationTypeObj: json['violation_type_obj'] != null ? ViolationType.fromJson(json['violation_type_obj']) : null,
      evidenceImage: json['evidence_image'],
      detectedLicensePlate: json['detected_license_plate'],
      confidenceScore: json['confidence_score']?.toDouble(),
      finePaid: json['fine_paid'] ?? false,
      paymentDate: json['payment_date'] != null ? DateTime.parse(json['payment_date']) : null,
      appealText: json['appeal_text'],
      appealDate: json['appeal_date'] != null ? DateTime.parse(json['appeal_date']) : null,
      appealStatus: json['appeal_status'],
      daysUntilDeadline: json['days_until_deadline'],
      vehicleDetails: json['vehicle_details'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'violation_type': violationType,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'fine_amount': fineAmount,
      'status': status,
      'evidence_url': evidenceUrl,
      'vehicle_id': vehicleId,
      'officer_id': officerId,
      'created_at': createdAt,
      'vehicle': vehicle?.toJson(),
      'officer': officer?.toJson(),
      'payment': payment,
      'license_plate': licensePlate,
      'violation_type_obj': violationTypeObj?.toJson(),
      'evidence_image': evidenceImage,
      'detected_license_plate': detectedLicensePlate,
      'confidence_score': confidenceScore,
      'fine_paid': finePaid,
      'payment_date': paymentDate?.toIso8601String(),
      'appeal_text': appealText,
      'appeal_date': appealDate?.toIso8601String(),
      'appeal_status': appealStatus,
      'days_until_deadline': daysUntilDeadline,
      'vehicle_details': vehicleDetails,
    };
  }
  
  Violation copyWith({
    int? id,
    String? violationType,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    String? timestamp,
    double? fineAmount,
    String? status,
    String? evidenceUrl,
    int? vehicleId,
    int? officerId,
    String? createdAt,
    Vehicle? vehicle,
    User? officer,
    Map<String, dynamic>? payment,
    String? licensePlate,
    ViolationType? violationTypeObj,
    String? evidenceImage,
    String? detectedLicensePlate,
    double? confidenceScore,
    bool? finePaid,
    DateTime? paymentDate,
    String? appealText,
    DateTime? appealDate,
    String? appealStatus,
    int? daysUntilDeadline,
    Map<String, dynamic>? vehicleDetails,
  }) {
    return Violation(
      id: id ?? this.id,
      violationType: violationType ?? this.violationType,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      fineAmount: fineAmount ?? this.fineAmount,
      status: status ?? this.status,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      vehicleId: vehicleId ?? this.vehicleId,
      officerId: officerId ?? this.officerId,
      createdAt: createdAt ?? this.createdAt,
      vehicle: vehicle ?? this.vehicle,
      officer: officer ?? this.officer,
      payment: payment ?? this.payment,
      licensePlate: licensePlate ?? this.licensePlate,
      violationTypeObj: violationTypeObj ?? this.violationTypeObj,
      evidenceImage: evidenceImage ?? this.evidenceImage,
      detectedLicensePlate: detectedLicensePlate ?? this.detectedLicensePlate,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      finePaid: finePaid ?? this.finePaid,
      paymentDate: paymentDate ?? this.paymentDate,
      appealText: appealText ?? this.appealText,
      appealDate: appealDate ?? this.appealDate,
      appealStatus: appealStatus ?? this.appealStatus,
      daysUntilDeadline: daysUntilDeadline ?? this.daysUntilDeadline,
      vehicleDetails: vehicleDetails ?? this.vehicleDetails,
    );
  }
  
  @override
  String toString() {
    return 'Violation{id: $id, type: $violationType, status: $status, amount: $fineAmount}';
  }
}
