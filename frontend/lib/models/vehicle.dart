class Vehicle {
  final int id;
  final String licensePlate;
  final String make;
  final String model;
  final String color;
  final int year;
  final String ownerName;
  final String type;
  final DateTime? registrationExpiry;
  final String? qrCodeUrl;
  final String? registrationNumber;

  Vehicle({
    required this.id,
    required this.licensePlate,
    required this.make,
    required this.model,
    required this.color,
    required this.year,
    required this.ownerName,
    required this.type,
    this.registrationExpiry,
    this.qrCodeUrl,
    this.registrationNumber,
  });

  // Add displayName getter
  String get displayName => '$make $model ($licensePlate)';

  // Check if registration is valid (not expired)
  bool get isRegistrationValid {
    if (registrationExpiry == null) return false;
    return registrationExpiry!.isAfter(DateTime.now());
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      licensePlate: json['license_plate'],
      make: json['make'],
      model: json['model'],
      color: json['color'],
      year: json['year'],
      ownerName: json['owner_name'],
      type: json['type'],
      registrationExpiry: json['registration_expiry'] != null
          ? DateTime.parse(json['registration_expiry'])
          : null,
      qrCodeUrl: json['qr_code_url'],
      registrationNumber: json['registration_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'license_plate': licensePlate,
      'make': make,
      'model': model,
      'color': color,
      'year': year,
      'owner_name': ownerName,
      'type': type,
      'registration_expiry': registrationExpiry?.toIso8601String(),
      'qr_code_url': qrCodeUrl,
      'registration_number': registrationNumber,
    };
  }

  @override
  String toString() {
    return 'Vehicle{id: $id, licensePlate: $licensePlate, make: $make, model: $model}';
  }
}
