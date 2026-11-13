import '../models/group.dart';
import 'api_client.dart';

/// Motoros csapatok (csoportok) kezelése a backend `GET/POST/PATCH/DELETE
/// /api/groups` végpontjain.
class GroupsService {
  GroupsService(this._client);

  final ApiClient _client;

  /// A bejelentkezett felhasználó csoportjai (tagként vagy tulajdonosként).
  Future<List<BikeGroup>> fetchGroups() async {
    final data = await _client.get('/groups');
    final items = data['groups'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => BikeGroup.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Egy csoport részletei (tagokkal).
  Future<BikeGroup> fetchGroup(String groupId) async {
    final data = await _client.get('/groups/$groupId');
    return BikeGroup.fromJson(data['group'] as Map<String, dynamic>);
  }

  /// Új csoport létrehozása (a létrehozó tulajdonos tag lesz).
  Future<BikeGroup> createGroup({
    required String name,
    String? description,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (description != null) {
      body['description'] = description;
    }

    final data = await _client.post('/groups', body: body);

    return BikeGroup.fromJson(data['group'] as Map<String, dynamic>);
  }

  /// Név / leírás módosítása (csak tulajdonos). Az üres leírás törli azt.
  Future<BikeGroup> updateGroup(
    String groupId, {
    required String name,
    String? description,
  }) async {
    final data = await _client.patch(
      '/groups/$groupId',
      body: <String, dynamic>{
        'name': name,
        'description': description ?? '',
      },
    );

    return BikeGroup.fromJson(data['group'] as Map<String, dynamic>);
  }

  /// Csoport törlése (csak tulajdonos).
  Future<void> deleteGroup(String groupId) async {
    await _client.delete('/groups/$groupId');
  }

  /// Tag hozzáadása barátból (csak tulajdonos).
  Future<BikeGroup> addMember(String groupId, {required String userId}) async {
    final data = await _client.post(
      '/groups/$groupId/members',
      body: <String, dynamic>{'userId': userId},
    );

    return BikeGroup.fromJson(data['group'] as Map<String, dynamic>);
  }

  /// Tag eltávolítása (tulajdonos) vagy saját kilépés a csoportból.
  Future<void> removeMember(String groupId, String userId) async {
    await _client.delete('/groups/$groupId/members/$userId');
  }
}
