class TrafficIncident {
  final int id;
  final String incidentType;
  final String? incidentTypeDisplay;
  final String description;
  final String? location;
  final double latitude;
  final double longitude;
  final int severity;
  final String? severityDisplay;
  final bool isVerified;
  final bool isResolved;
  final bool isActive;
  final int reportedById;
  final String? reportedByName;
  final int? verifiedById;
  final String? verifiedByName;
  final String reportedAt;
  final String? verifiedAt;
  final String? resolvedAt;

  TrafficIncident({
    required this.id,
    required this.incidentType,
    this.incidentTypeDisplay,
    required this.description,
    this.location,
    required this.latitude,
    required this.longitude,
    required this.severity,
    this.severityDisplay,
    required this.isVerified,
    required this.isResolved,
    required this.isActive,
    required this.reportedById,
    this.reportedByName,
    this.verifiedById,
    this.verifiedByName,
    required this.reportedAt,
    this.verifiedAt,
    this.resolvedAt,
  });

  factory TrafficIncident.fromJson(Map<String, dynamic> json) {
    return TrafficIncident(
      id: json['id'],
      incidentType: json['incident_type'],
      incidentTypeDisplay: json['incident_type_display'],
      description: json['description'],
      location: json['location'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      severity: json['severity'],
      severityDisplay: json['severity_display'],
      isVerified: json['is_verified'] ?? false,
      isResolved: json['is_resolved'] ?? false,
      isActive: json['is_active'] ?? true,
      reportedById: json['reported_by_id'],
      reportedByName: json['reported_by_name'],
      verifiedById: json['verified_by_id'],
      verifiedByName: json['verified_by_name'],
      reportedAt: json['reported_at'],
      verifiedAt: json['verified_at'],
      resolvedAt: json['resolved_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_type': incidentType,
      'incident_type_display': incidentTypeDisplay,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'severity_display': severityDisplay,
      'is_verified': isVerified,
      'is_resolved': isResolved,
      'is_active': isActive,
      'reported_by_id': reportedById,
      'reported_by_name': reportedByName,
      'verified_by_id': verifiedById,
      'verified_by_name': verifiedByName,
      'reported_at': reportedAt,
      'verified_at': verifiedAt,
      'resolved_at': resolvedAt,
    };
  }
}
