class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double intensity;

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      latitude: json['lat'].toDouble(),
      longitude: json['lng'].toDouble(),
      intensity: json['weight'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'weight': intensity,
    };
  }

  // Conversion to LatLng for Google Maps
  dynamic toLatLng() {
    return {
      'lat': latitude,
      'lng': longitude,
      'weight': intensity
    };
  }
}
