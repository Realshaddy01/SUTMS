
class User {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final String userType;
  final String? address;
  final String? badgeNumber;
  final String? token;
  final DateTime? createdAt;
  final bool? isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.phoneNumber,
    required this.userType,
    this.address,
    this.badgeNumber,
    this.token,
    this.createdAt,
    this.isActive,
  });

  bool get isOfficer => userType == 'officer';
  bool get isAdmin => userType == 'admin';
  bool get isVehicleOwner => userType == 'vehicle_owner';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      userType: json['user_type'] ?? 'vehicle_owner',
      address: json['address'],
      badgeNumber: json['badge_number'],
      token: json['token'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'user_type': userType,
      'address': address,
      'badge_number': badgeNumber,
      'token': token,
      'created_at': createdAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? userType,
    String? address,
    String? badgeNumber,
    String? token,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType ?? this.userType,
      address: address ?? this.address,
      badgeNumber: badgeNumber ?? this.badgeNumber,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, role: $userType}';
  }
}
