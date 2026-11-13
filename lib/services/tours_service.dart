import '../models/tour.dart';
import 'api_client.dart';

/// Túrák kezelése a backend `GET/POST/PATCH/DELETE /api/tours` végpontjain.
///
/// A létrehozó felhasználó túravezető lesz; a meghívott barátok és a
/// csoportok tagjai `invited` állapotban kerülnek a túrához.
class ToursService {
  ToursService(this._client);

  final ApiClient _client;

  /// A bejelentkezett felhasználó túrái (vezetőként vagy résztvevőként).
  Future<List<BikeTour>> fetchTours() async {
    final data = await _client.get('/tours');
    final items = data['tours'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => BikeTour.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Egy túra részletei (résztvevőkkel).
  Future<BikeTour> fetchTour(String tourId) async {
    final data = await _client.get('/tours/$tourId');
    return BikeTour.fromJson(data['tour'] as Map<String, dynamic>);
  }

  /// Új túra létrehozása.
  ///
  /// [status] jellemzően `draft` (mentés) vagy `active` (indítás). A
  /// [inviteUserIds] barátok, az [inviteGroupIds] saját csoportok azonosítói.
  Future<BikeTour> createTour({
    required String originName,
    required String destinationName,
    String? title,
    String status = 'planned',
    List<String> inviteUserIds = const <String>[],
    List<String> inviteGroupIds = const <String>[],
  }) async {
    final body = <String, dynamic>{
      'originName': originName,
      'destinationName': destinationName,
      'status': status,
    };

    if (title != null && title.isNotEmpty) {
      body['title'] = title;
    }
    if (inviteUserIds.isNotEmpty) {
      body['inviteUserIds'] = inviteUserIds;
    }
    if (inviteGroupIds.isNotEmpty) {
      body['inviteGroupIds'] = inviteGroupIds;
    }

    final data = await _client.post('/tours', body: body);

    return BikeTour.fromJson(data['tour'] as Map<String, dynamic>);
  }

  /// Túra címének / státuszának módosítása (csak vezető).
  Future<BikeTour> updateTour(
    String tourId, {
    String? title,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) {
      body['title'] = title;
    }
    if (status != null) {
      body['status'] = status;
    }

    final data = await _client.patch('/tours/$tourId', body: body);
    return BikeTour.fromJson(data['tour'] as Map<String, dynamic>);
  }

  /// Résztvevő meghívása barátból vagy csoportból (csak vezető).
  Future<BikeTour> inviteMember(
    String tourId, {
    String? userId,
    String? groupId,
  }) async {
    final body = <String, dynamic>{};
    if (userId != null) {
      body['userId'] = userId;
    }
    if (groupId != null) {
      body['groupId'] = groupId;
    }

    final data = await _client.post('/tours/$tourId/members', body: body);
    return BikeTour.fromJson(data['tour'] as Map<String, dynamic>);
  }

  /// Meghívás elfogadása vagy elutasítása (a meghívott saját válasza).
  Future<BikeTour> respondToInvite(
    String tourId, {
    required bool accept,
  }) async {
    final data = await _client.patch(
      '/tours/$tourId/members/me',
      body: <String, dynamic>{'status': accept ? 'accepted' : 'declined'},
    );

    return BikeTour.fromJson(data['tour'] as Map<String, dynamic>);
  }

  /// Résztvevő eltávolítása (vezető) vagy a részvétel lemondása (saját maga).
  Future<void> removeMember(String tourId, String userId) async {
    await _client.delete('/tours/$tourId/members/$userId');
  }

  /// Túra törlése (csak vezető).
  Future<void> deleteTour(String tourId) async {
    await _client.delete('/tours/$tourId');
  }
}
