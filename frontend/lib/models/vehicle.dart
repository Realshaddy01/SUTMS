import 'dart:convert';

class Vehicle {
  final int id;
  final String licensePlate;
  final String vehicleType;
  final String? make;
  final String? model;
  final String? color;
  final int? year;
  final String? registrationDate;
  final int ownerId;
  final String? qrCode;
  final String? createdAt;
  
  Vehicle({
    required this.id,
    required this.licensePlate,
    required this.vehicleType,
    this.make,
    this.model,
    this.color,
    this.year,
    this.registrationDate,
    required this.ownerId,
    this.qrCode,
    this.createdAt,
  });
  
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      licensePlate: json['license_plate'],
      vehicleType: json['vehicle_type'],
      make: json['make'],
      model: json['model'],
      color: json['color'],
      year: json['year'],
      registrationDate: json['registration_date'],
      ownerId: json['owner_id'],
      qrCode: json['qr_code'],
      createdAt: json['created_at'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'license_plate': licensePlate,
      'vehicle_type': vehicleType,
      'make': make,
      'model': model,
      'color': color,
      'year': year,
      'registration_date': registrationDate,
      'owner_id': ownerId,
      'qr_code': qrCode,
      'created_at': createdAt,
    };
  }
  
  @override
  String toString() {
    return 'Vehicle{id: $id, licensePlate: $licensePlate, type: $vehicleType, make: $make, model: $model}';
  }
}
