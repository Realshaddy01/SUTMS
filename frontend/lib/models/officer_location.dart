class OfficerLocation {
  final int id;
  final int officerId;
  final String officerName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final bool isActive;
  final int? batteryLevel;
  final String timestamp;

  OfficerLocation({
    required this.id,
    required this.officerId,
    required this.officerName,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.isActive,
    this.batteryLevel,
    required this.timestamp,
  });

  factory OfficerLocation.fromJson(Map<String, dynamic> json) {
    return OfficerLocation(
      id: json['id'],
      officerId: json['officer_id'],
      officerName: json['officer_name'] ?? 'Unknown Officer',
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      accuracy: json['accuracy']?.toDouble(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
      isActive: json['is_active'] ?? false,
      batteryLevel: json['battery_level'],
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'officer_id': officerId,
      'officer_name': officerName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'is_active': isActive,
      'battery_level': batteryLevel,
      'timestamp': timestamp,
    };
  }
}
