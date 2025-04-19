import './user.dart';

class AuthResult {
  final String token;
  final String refreshToken;
  final User user;

  AuthResult({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    // Handle different response formats
    String tokenValue;
    Map<String, dynamic> userData;
    
    if (json.containsKey('token')) {
      tokenValue = json['token'];
    } else if (json.containsKey('key')) {
      tokenValue = json['key'];
    } else {
      tokenValue = '';
    }
    
    if (json.containsKey('user')) {
      userData = json['user'];
    } else {
      // If the user data is at the root level
      userData = json;
    }
    
    return AuthResult(
      token: tokenValue,
      refreshToken: json['refresh_token'] ?? '',
      user: User.fromJson(userData),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refresh_token': refreshToken,
      'user': user.toJson(),
    };
  }
} 