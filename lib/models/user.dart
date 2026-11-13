/// A bejelentkezett felhasználó adatai (a backend `users` táblájának tükrözése).
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.motorcycle,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      motorcycle: json['motorcycle'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String? motorcycle;
  final DateTime? createdAt;

  /// Monogram a profil körben (pl. "Kovács Béla" -> "KB").
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'displayName': displayName,
    'motorcycle': motorcycle,
    'createdAt': createdAt?.toIso8601String(),
  };
}
