import 'initials.dart';

/// Egy túra résztvevője a backend `Tour` válaszának `members` listájából.
class TourMember {
  const TourMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.status,
    this.email,
    this.motorcycle,
    this.isSelf = false,
  });

  factory TourMember.fromJson(Map<String, dynamic> json) {
    return TourMember(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'invited',
      email: json['email'] as String?,
      motorcycle: json['motorcycle'] as String?,
      isSelf: json['isSelf'] as bool? ?? false,
    );
  }

  final String userId;
  final String displayName;

  /// `leader` (túravezető) vagy `member`.
  final String role;

  /// `invited`, `accepted` vagy `declined`.
  final String status;
  final String? email;
  final String? motorcycle;

  /// Igaz, ha ez a sor a bejelentkezett felhasználó.
  final bool isSelf;

  bool get isLeader => role == 'leader';
  bool get isAccepted => status == 'accepted';
  bool get isInvited => status == 'invited';
  bool get isDeclined => status == 'declined';

  String get initials => initialsFromName(displayName);
}

/// Túra a backendről (tervezés, mentés, meghívás).
class BikeTour {
  const BikeTour({
    required this.id,
    required this.title,
    required this.originName,
    required this.destinationName,
    required this.status,
    required this.createdBy,
    required this.members,
    this.memberCount = 0,
    this.myRole,
    this.myStatus,
    this.distanceM,
    this.durationS,
    this.scheduledAt,
    this.createdAt,
    this.updatedAt,
  });

  factory BikeTour.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List<dynamic>? ?? const <dynamic>[];
    final parsedMembers = members
        .map((item) => TourMember.fromJson(item as Map<String, dynamic>))
        .toList();

    return BikeTour(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      originName: json['originName'] as String? ?? '',
      destinationName: json['destinationName'] as String? ?? '',
      status: json['status'] as String? ?? 'planned',
      createdBy: json['createdBy'] as String? ?? '',
      members: parsedMembers,
      memberCount: json['memberCount'] as int? ?? parsedMembers.length,
      myRole: json['myRole'] as String?,
      myStatus: json['myStatus'] as String?,
      distanceM: json['distanceM'] as int?,
      durationS: json['durationS'] as int?,
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  final String id;
  final String title;
  final String originName;
  final String destinationName;

  /// `draft`, `planned`, `active` vagy `finished`.
  final String status;
  final String createdBy;
  final List<TourMember> members;
  final int memberCount;

  /// A bejelentkezett felhasználó szerepe (`leader` / `member`) és állapota.
  final String? myRole;
  final String? myStatus;
  final int? distanceM;
  final int? durationS;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLeader => myRole == 'leader';
  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  /// Az aktuális felhasználó részvétele (`accepted`, ha nincs adat).
  String get myParticipation => myStatus ?? 'accepted';

  /// Például: `Jelenlegi hely ➔ Eger`.
  String get routeLabel => '$originName ➔ $destinationName';

  /// Az elfogadott résztvevők (a vezetővel együtt).
  List<TourMember> get acceptedMembers =>
      members.where((member) => member.isAccepted).toList();

  TourMember? get selfMember {
    for (final member in members) {
      if (member.isSelf) {
        return member;
      }
    }
    return null;
  }

  String get initials => initialsFromName(title);
}
