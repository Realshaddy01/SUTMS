class ViolationType {
  final int id;
  final String name;
  final String code;
  final String description;
  final double baseFine;
  final String severity;

  ViolationType({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.baseFine,
    required this.severity,
  });

  // Getter for formatted fine
  String get formattedFine => 'Npr ${baseFine.toStringAsFixed(2)}';

  factory ViolationType.fromJson(Map<String, dynamic> json) {
    return ViolationType(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      baseFine: double.parse(json['base_fine'].toString()),
      severity: json['severity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'base_fine': baseFine,
      'severity': severity,
    };
  }
}
