import 'dart:convert';
import 'user.dart';
import 'vehicle.dart';

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
  });
  
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
    );
  }
  
  @override
  String toString() {
    return 'Violation{id: $id, type: $violationType, status: $status, amount: $fineAmount}';
  }
}
