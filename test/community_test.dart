import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:moto_konvoj/screens/community_screen.dart';
import 'package:moto_konvoj/services/api_client.dart';
import 'package:moto_konvoj/services/friends_service.dart';
import 'package:moto_konvoj/services/groups_service.dart';

/// Memóriabeli "backend" a közösség képernyő widget tesztjeihez.
class _FakeBackend {
  _FakeBackend({bool withGroup = false}) {
    if (withGroup) {
      groups.add(_groupJson(
        id: 'g1',
        name: 'Betyár Riders Klub',
        description: 'Hétvégi túrák',
        members: <Map<String, dynamic>>[
          _memberJson('me', 'Smoke Anna', 'owner', isSelf: true),
        ],
      ));
    }
  }

  final List<String> calls = <String>[];

  final Map<String, Map<String, dynamic>> friends = <String, Map<String, dynamic>>{
    'f1': <String, dynamic>{
      'id': 'f1',
      'displayName': 'Kovács Ádám',
      'email': 'adam@example.com',
      'motorcycle': 'BMW R1250GS',
      'friendsSince': '2026-01-01T10:00:00.000Z',
    },
  };

  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'r1',
      'status': 'pending',
      'direction': 'incoming',
      'createdAt': '2026-02-01T10:00:00.000Z',
      'requester': <String, dynamic>{'id': 'u9', 'displayName': 'Tóth Bence'},
      'addressee': <String, dynamic>{'id': 'me', 'displayName': 'Smoke Anna'},
    },
  ];

  final List<Map<String, dynamic>> groups = <Map<String, dynamic>>[];

  int _groupCounter = 1;

  static Map<String, dynamic> _memberJson(
    String userId,
    String displayName,
    String role, {
    bool isSelf = false,
  }) {
    return <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'role': role,
      'isSelf': isSelf,
    };
  }

  static Map<String, dynamic> _groupJson({
    required String id,
    required String name,
    String? description,
    List<Map<String, dynamic>>? members,
  }) {
    final memberList = members ?? <Map<String, dynamic>>[
      _memberJson('me', 'Smoke Anna', 'owner', isSelf: true),
    ];

    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'ownerId': 'me',
      'createdAt': '2026-03-01T10:00:00.000Z',
      'updatedAt': '2026-03-01T10:00:00.000Z',
      'memberCount': memberList.length,
      'myRole': 'owner',
      'members': memberList,
    };
  }

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final segments = request.url.pathSegments;
    final method = request.method;
    calls.add('$method $path');

    Map<String, dynamic> body() {
      if (request.body.isEmpty) {
        return <String, dynamic>{};
      }
      return jsonDecode(request.body) as Map<String, dynamic>;
    }

    // --- Barátok ---
    if (method == 'GET' && path == '/api/friends') {
      return _json(<String, dynamic>{'friends': friends.values.toList()});
    }

    if (method == 'GET' && path == '/api/friends/requests') {
      final pending = requests
          .where((request) => request['status'] == 'pending')
          .toList();
      return _json(<String, dynamic>{'pending': pending, 'history': []});
    }

    if (method == 'GET' && path == '/api/users/search') {
      return _json(<String, dynamic>{
        'users': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'u10',
            'email': 'uj@example.com',
            'displayName': 'Új Ember',
          },
        ],
      });
    }

    if (method == 'POST' && path == '/api/friends/requests') {
      final payload = body();
      requests.add(<String, dynamic>{
        'id': 'r-new',
        'status': 'pending',
        'direction': 'outgoing',
        'requester': <String, dynamic>{'id': 'me', 'displayName': 'Smoke Anna'},
        'addressee': <String, dynamic>{
          'id': payload['userId'],
          'displayName': 'Új Ember',
        },
      });
      return _json(<String, dynamic>{'request': requests.last}, status: 201);
    }

    if (method == 'POST' &&
        segments.length == 5 &&
        segments[2] == 'requests' &&
        segments[4] == 'accept') {
      final id = segments[3];
      requests.removeWhere((request) => request['id'] == id);
      friends['u9'] = <String, dynamic>{
        'id': 'u9',
        'displayName': 'Tóth Bence',
        'email': 'bence@example.com',
        'friendsSince': '2026-02-02T10:00:00.000Z',
      };
      return _json(<String, dynamic>{'accepted': true});
    }

    if (method == 'POST' &&
        segments.length == 5 &&
        segments[2] == 'requests' &&
        segments[4] == 'decline') {
      final id = segments[3];
      requests.removeWhere((request) => request['id'] == id);
      return _json(<String, dynamic>{'declined': true});
    }

    if (method == 'DELETE' &&
        segments.length == 4 &&
        segments[2] == 'requests') {
      final id = segments[3];
      requests.removeWhere((request) => request['id'] == id);
      return http.Response('', 204);
    }

    if (method == 'DELETE' && segments.length == 3 && segments[1] == 'friends') {
      friends.remove(segments[2]);
      return http.Response('', 204);
    }

    return _groups(method, segments, body);
  }

  http.Response _json(Map<String, dynamic> data, {int status = 200}) {
    return http.Response(
      jsonEncode(data),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }

  http.Response _groups(
    String method,
    List<String> segments,
    Map<String, dynamic> Function() body,
  ) {
    if (method == 'GET' && segments.length == 2 && segments[1] == 'groups') {
      return _json(<String, dynamic>{'groups': groups});
    }

    if (method == 'POST' && segments.length == 2 && segments[1] == 'groups') {
      final payload = body();
      final group = _groupJson(
        id: 'g${++_groupCounter}',
        name: payload['name'] as String,
        description: payload['description'] as String?,
      );
      groups.add(group);
      return _json(<String, dynamic>{'group': group}, status: 201);
    }

    if (segments.length >= 3 && segments[1] == 'groups') {
      final matches = groups.where((item) => item['id'] == segments[2]);

      if (matches.isEmpty) {
        return _json(<String, dynamic>{
          'error': <String, dynamic>{'message': 'Nincs ilyen csoport.'},
        }, status: 404);
      }

      final group = matches.first;
      final members = group['members'] as List<dynamic>;

      if (method == 'PATCH' && segments.length == 3) {
        final payload = body();
        group['name'] = payload['name'];
        group['description'] = payload['description'];
        return _json(<String, dynamic>{'group': group});
      }

      if (method == 'DELETE' && segments.length == 3) {
        groups.remove(group);
        return http.Response('', 204);
      }

      if (method == 'POST' && segments.length == 4 && segments[3] == 'members') {
        final payload = body();
        members.add(_memberJson(payload['userId'] as String, 'Új Tag', 'member'));
        group['memberCount'] = members.length;
        return _json(<String, dynamic>{'group': group}, status: 201);
      }

      if (method == 'DELETE' &&
          segments.length == 5 &&
          segments[3] == 'members') {
        members.removeWhere(
          (member) =>
              (member as Map<String, dynamic>)['userId'] == segments[4],
        );
        group['memberCount'] = members.length;
        return http.Response('', 204);
      }
    }

    return _json(<String, dynamic>{
      'error': <String, dynamic>{
        'message': 'Nem támogatott kérés: $method ${segments.join('/')}',
      },
    }, status: 400);
  }
}

Widget _buildApp(_FakeBackend backend) {
  final client = ApiClient(
    httpClient: backend.client,
    baseUrl: 'http://test/api',
  );

  return MultiProvider(
    providers: [
      Provider<FriendsService>.value(value: FriendsService(client)),
      Provider<GroupsService>.value(value: GroupsService(client)),
    ],
    child: const MaterialApp(home: CommunityScreen()),
  );
}

/// Magasabb tesztfelület, hogy a lista minden szekciója kirajzolódjon.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('A barátok és a kérések a backendről töltődnek be', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final backend = _FakeBackend();

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    expect(find.text('Barátaim (1)'), findsOneWidget);
    expect(find.text('Kovács Ádám'), findsOneWidget);
    expect(find.text('Bejövő barátkérések (1)'), findsOneWidget);
    expect(find.text('Tóth Bence'), findsOneWidget);
  });

  testWidgets('A bejövő barátkérés elfogadható', (WidgetTester tester) async {
    _useTallSurface(tester);
    final backend = _FakeBackend();

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acceptRequest_r1')));
    await tester.pumpAndSettle();

    expect(
      backend.calls.contains('POST /api/friends/requests/r1/accept'),
      isTrue,
    );
    expect(find.text('Barátaim (2)'), findsOneWidget);
    expect(find.text('Bejövő barátkérések (1)'), findsNothing);
  });

  testWidgets('Barát eltávolítása megerősítés után történik meg', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final backend = _FakeBackend();

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('removeFriend_f1')));
    await tester.pumpAndSettle();

    expect(find.text('Barát eltávolítása'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmActionButton')));
    await tester.pumpAndSettle();

    expect(backend.calls.contains('DELETE /api/friends/f1'), isTrue);
    expect(find.text('Barátaim (0)'), findsOneWidget);
  });

  testWidgets('Barát kereshető és barátkérés küldhető', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final backend = _FakeBackend();

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('friendSearchField')),
      'Új',
    );
    await tester.tap(find.byKey(const Key('friendSearchButton')));
    await tester.pumpAndSettle();

    expect(find.text('Új Ember'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sendRequest_u10')));
    await tester.pumpAndSettle();

    expect(backend.calls.contains('POST /api/friends/requests'), isTrue);
    // A kérés elküldése után az "Elküldött kérések" szekció jelenik meg.
    expect(find.text('Elküldött kérések (1)'), findsOneWidget);
  });

  testWidgets('Új csoport hozható létre a dialógusból', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final backend = _FakeBackend();

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Csoportok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('createGroupButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('groupNameField')),
      'Teszt Csapat',
    );
    await tester.tap(find.byKey(const Key('groupSaveButton')));
    await tester.pumpAndSettle();

    expect(backend.calls.contains('POST /api/groups'), isTrue);
    expect(find.text('Csoportjaim (1)'), findsOneWidget);
    expect(find.text('Teszt Csapat'), findsOneWidget);
  });

  testWidgets('Csoporthoz tag adható és a csoport átnevezhető', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final backend = _FakeBackend(withGroup: true);

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Csoportok'));
    await tester.pumpAndSettle();

    expect(find.text('Betyár Riders Klub'), findsOneWidget);

    // Tag hozzáadása a barátlistából.
    await tester.tap(find.byKey(const Key('addMember_g1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addMemberCandidate_f1')));
    await tester.pumpAndSettle();

    expect(backend.calls.contains('POST /api/groups/g1/members'), isTrue);
    expect(find.byKey(const Key('memberChip_f1')), findsOneWidget);

    // Átnevezés a szerkesztő dialógussal.
    await tester.tap(find.byKey(const Key('editGroup_g1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('groupNameField')),
      'Betyár Riders Team',
    );
    await tester.tap(find.byKey(const Key('groupSaveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Betyár Riders Team'), findsOneWidget);
    expect(find.text('Betyár Riders Klub'), findsNothing);
  });

  testWidgets('A csoport törölhető a megerősítés után', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final backend = _FakeBackend(withGroup: true);

    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Csoportok'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteGroup_g1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmActionButton')));
    await tester.pumpAndSettle();

    expect(backend.calls.contains('DELETE /api/groups/g1'), isTrue);
    expect(find.text('Csoportjaim (0)'), findsOneWidget);
  });
}


