/// Egy barátkérés a backend `GET /api/friends/requests` válaszából.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.status,
    required this.direction,
    required this.requesterId,
    required this.requesterName,
    required this.addresseeId,
    required this.addresseeName,
    this.createdAt,
    this.respondedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] as Map<String, dynamic>? ?? const {};
    final addressee = json['addressee'] as Map<String, dynamic>? ?? const {};

    return FriendRequest(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      direction: json['direction'] as String? ?? 'outgoing',
      requesterId: requester['id'] as String? ?? '',
      requesterName: requester['displayName'] as String? ?? '',
      addresseeId: addressee['id'] as String? ?? '',
      addresseeName: addressee['displayName'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      respondedAt: DateTime.tryParse(json['respondedAt'] as String? ?? ''),
    );
  }

  final String id;
  final String status;

  /// `incoming` (nekünk küldték) vagy `outgoing` (mi küldtük).
  final String direction;
  final String requesterId;
  final String requesterName;
  final String addresseeId;
  final String addresseeName;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  bool get isIncoming => direction == 'incoming';

  bool get isPending => status == 'pending';

  /// A másik fél azonosítója (akitől jött, vagy akinek küldtük).
  String get otherUserId => isIncoming ? requesterId : addresseeId;

  /// A másik fél megjelenített neve.
  String get otherDisplayName =>
      isIncoming ? requesterName : addresseeName;
}
