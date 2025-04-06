import 'dart:convert';

class User {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final String role;
  final bool isActive;
  final String? createdAt;
  
  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.phoneNumber,
    required this.role,
    required this.isActive,
    this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      role: json['role'],
      isActive: json['is_active'],
      createdAt: json['created_at'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
  
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    bool? isActive,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  @override
  String toString() {
    return 'User{id: $id, username: $username, role: $role}';
  }
}
