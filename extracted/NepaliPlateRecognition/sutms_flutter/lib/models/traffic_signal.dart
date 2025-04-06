class TrafficSignal {
  final int id;
  final String name;
  final String streetName;
  final double latitude;
  final double longitude;
  final String status;
  final String currentPhase;
  final int? timeRemaining;
  final bool isAutomated;
  final String? lastUpdated;
  final String? lastUpdatedBy;

  TrafficSignal({
    required this.id,
    required this.name,
    required this.streetName,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.currentPhase,
    this.timeRemaining,
    required this.isAutomated,
    this.lastUpdated,
    this.lastUpdatedBy,
  });

  factory TrafficSignal.fromJson(Map<String, dynamic> json) {
    return TrafficSignal(
      id: json['id'],
      name: json['name'],
      streetName: json['street_name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      status: json['status'],
      currentPhase: json['current_phase'],
      timeRemaining: json['time_remaining'],
      isAutomated: json['is_automated'] ?? true,
      lastUpdated: json['last_updated'],
      lastUpdatedBy: json['last_updated_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'street_name': streetName,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'current_phase': currentPhase,
      'time_remaining': timeRemaining,
      'is_automated': isAutomated,
      'last_updated': lastUpdated,
      'last_updated_by': lastUpdatedBy,
    };
  }
}
