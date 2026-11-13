import 'initials.dart';

/// Egy csoport egy tagja a backend `GET /api/groups` válaszából.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    this.email,
    this.motorcycle,
    this.isSelf = false,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      email: json['email'] as String?,
      motorcycle: json['motorcycle'] as String?,
      isSelf: json['isSelf'] as bool? ?? false,
    );
  }

  final String userId;
  final String displayName;

  /// `owner` vagy `member`.
  final String role;
  final String? email;
  final String? motorcycle;

  /// Igaz, ha ez a sor a bejelentkezett felhasználó.
  final bool isSelf;

  bool get isOwner => role == 'owner';

  String get initials => initialsFromName(displayName);
}

/// Motoros csapat (csoport) a backendről, a tagok listájával együtt.
class BikeGroup {
  const BikeGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberCount,
    required this.myRole,
    required this.members,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory BikeGroup.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List<dynamic>? ?? const <dynamic>[];
    final parsedMembers = members
        .map((item) => GroupMember.fromJson(item as Map<String, dynamic>))
        .toList();

    return BikeGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      memberCount: json['memberCount'] as int? ?? parsedMembers.length,
      myRole: json['myRole'] as String? ?? 'member',
      members: parsedMembers,
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  final String id;
  final String name;
  final String ownerId;
  final int memberCount;

  /// A bejelentkezett felhasználó szerepe a csoportban (`owner` / `member`).
  final String myRole;
  final List<GroupMember> members;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOwner => myRole == 'owner';

  /// Az aktuális felhasználó tagsági sora (kilépéshez).
  GroupMember? get selfMember {
    for (final member in members) {
      if (member.isSelf) {
        return member;
      }
    }
    return null;
  }

  String get initials => initialsFromName(name);
}
