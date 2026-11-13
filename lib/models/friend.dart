/// Egy barát a backend `GET /api/friends` válaszából.
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    this.email,
    this.motorcycle,
    this.friendsSince,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String?,
      motorcycle: json['motorcycle'] as String?,
      friendsSince: DateTime.tryParse(json['friendsSince'] as String? ?? ''),
    );
  }

  final String id;
  final String displayName;
  final String? email;
  final String? motorcycle;
  final DateTime? friendsSince;

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
}
