import 'user.dart';

/// Bejelentkezés/regisztráció válasza: JWT token + felhasználó.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String token;
  final User user;
}
