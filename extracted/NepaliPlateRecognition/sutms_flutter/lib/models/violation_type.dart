import 'dart:convert';

class ViolationType {
  final int id;
  final String name;
  final String description;
  final double defaultFine;
  final bool isActive;
  final String? createdAt;
  
  ViolationType({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultFine,
    required this.isActive,
    this.createdAt,
  });
  
  factory ViolationType.fromJson(Map<String, dynamic> json) {
    return ViolationType(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      defaultFine: json['default_fine'].toDouble(),
      isActive: json['is_active'],
      createdAt: json['created_at'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'default_fine': defaultFine,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
  
  @override
  String toString() {
    return 'ViolationType{id: $id, name: $name, defaultFine: $defaultFine}';
  }
}
