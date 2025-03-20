class Vehicle {
  final int id;
  final int ownerId;
  final String licensePlate;
  final String vehicleType;
  final String make;
  final String model;
  final int year;
  final String color;
  final String registrationNumber;
  final String? insuranceNumber;
  final String? insuranceExpiry;
  final String? vehicleImage;
  final String? qrCode;
  final String createdAt;
  final String updatedAt;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.licensePlate,
    required this.vehicleType,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.registrationNumber,
    this.insuranceNumber,
    this.insuranceExpiry,
    this.vehicleImage,
    this.qrCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      ownerId: json['owner'],
      licensePlate: json['license_plate'],
      vehicleType: json['vehicle_type'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      registrationNumber: json['registration_number'],
      insuranceNumber: json['insurance_number'],
      insuranceExpiry: json['insurance_expiry'],
      vehicleImage: json['vehicle_image'],
      qrCode: json['qr_code'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': ownerId,
      'license_plate': licensePlate,
      'vehicle_type': vehicleType,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'registration_number': registrationNumber,
      'insurance_number': insuranceNumber,
      'insurance_expiry': insuranceExpiry,
      'vehicle_image': vehicleImage,
      'qr_code': qrCode,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get displayName => '$make $model ($year)';
}

