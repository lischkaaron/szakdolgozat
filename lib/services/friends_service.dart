import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import 'api_client.dart';

/// Barátlistával és barátkérésekkel kapcsolatos API hívások.
class FriendsService {
  FriendsService(this._client);

  final ApiClient _client;

  /// A bejelentkezett felhasználó barátai (`GET /api/friends`).
  Future<List<Friend>> fetchFriends() async {
    final data = await _client.get('/friends');
    final items = data['friends'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => Friend.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Függő (pending) barátkérések: bejövők és kimenők vegyesen.
  Future<List<FriendRequest>> fetchPendingRequests() async {
    final data = await _client.get('/friends/requests');
    final items = data['pending'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => FriendRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Felhasználó keresése név vagy e-mail alapján (`GET /api/users/search`).
  Future<List<User>> searchUsers(String query) async {
    final data = await _client.get(
      '/users/search?q=${Uri.encodeQueryComponent(query)}',
    );
    final items = data['users'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Barátkérés küldése azonosító vagy e-mail alapján.
  Future<void> sendRequest({String? userId, String? email}) async {
    final body = <String, dynamic>{};
    if (userId != null) {
      body['userId'] = userId;
    }
    if (email != null) {
      body['email'] = email;
    }

    await _client.post('/friends/requests', body: body);
  }

  /// Bejövő kérés elfogadása (csak a címzett hívhatja).
  Future<void> acceptRequest(String requestId) async {
    await _client.post('/friends/requests/$requestId/accept');
  }

  /// Bejövő kérés elutasítása (csak a címzett hívhatja).
  Future<void> declineRequest(String requestId) async {
    await _client.post('/friends/requests/$requestId/decline');
  }

  /// Saját, még függő kérés visszavonása.
  Future<void> cancelRequest(String requestId) async {
    await _client.delete('/friends/requests/$requestId');
  }

  /// Barátság megszüntetése (mindkét irányban).
  Future<void> removeFriend(String friendId) async {
    await _client.delete('/friends/$friendId');
  }
}

