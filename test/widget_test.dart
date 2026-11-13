import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:moto_konvoj/screens/main_navigation_screen.dart';
import 'package:moto_konvoj/services/api_client.dart';
import 'package:moto_konvoj/services/friends_service.dart';
import 'package:moto_konvoj/services/groups_service.dart';
import 'package:moto_konvoj/services/tours_service.dart';

/// Memóriabeli "backend" a tervező widget tesztjeihez.
///
/// A barát- és csoportlistát, valamint a túra létrehozását szolgálja ki,
/// így a teljes tervezési folyamat végigjárható valós service-eken keresztül.
class _PlannerBackend {
  final List<String> calls = <String>[];
  final List<Map<String, dynamic>> tours = <Map<String, dynamic>>[];

  Map<String, dynamic>? lastTourBody;

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final method = request.method;
    calls.add('$method $path');

    Map<String, dynamic> body() {
      if (request.body.isEmpty) {
        return <String, dynamic>{};
      }
      return jsonDecode(request.body) as Map<String, dynamic>;
    }

    if (method == 'GET' && path == '/api/friends') {
      return _json(<String, dynamic>{
        'friends': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'f1',
            'displayName': 'Kovács Ádám',
            'email': 'adam@example.com',
            'motorcycle': 'BMW R1250GS',
          },
        ],
      });
    }

    if (method == 'GET' && path == '/api/groups') {
      return _json(<String, dynamic>{
        'groups': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'g1',
            'name': 'Betyár Riders Klub',
            'ownerId': 'me',
            'memberCount': 1,
            'myRole': 'owner',
            'members': <Map<String, dynamic>>[
              <String, dynamic>{
                'userId': 'me',
                'displayName': 'Smoke Anna',
                'role': 'owner',
                'isSelf': true,
              },
            ],
          },
        ],
      });
    }

    if (method == 'GET' && path == '/api/tours') {
      return _json(<String, dynamic>{'tours': tours});
    }

    if (method == 'POST' && path == '/api/tours') {
      lastTourBody = body();
      final tour = _tourJson(lastTourBody!);
      tours.add(tour);
      return _json(<String, dynamic>{'tour': tour}, status: 201);
    }

    return _json(<String, dynamic>{
      'error': <String, dynamic>{
        'message': 'Nem támogatott kérés: $method $path',
      },
    }, status: 400);
  }

  Map<String, dynamic> _tourJson(Map<String, dynamic> payload) {
    final members = <Map<String, dynamic>>[
      <String, dynamic>{
        'userId': 'me',
        'displayName': 'Smoke Anna',
        'role': 'leader',
        'status': 'accepted',
        'isSelf': true,
      },
    ];

    for (final id in payload['inviteUserIds'] as List<dynamic>? ??
        const <dynamic>[]) {
      members.add(<String, dynamic>{
        'userId': id,
        'displayName': 'Kovács Ádám',
        'role': 'member',
        'status': 'invited',
        'isSelf': false,
      });
    }

    return <String, dynamic>{
      'id': 't${tours.length + 1}',
      'title': payload['title'] ?? 'Jelenlegi hely ➔ Eger',
      'originName': payload['originName'],
      'destinationName': payload['destinationName'],
      'status': payload['status'],
      'createdBy': 'me',
      'memberCount': members.length,
      'myRole': 'leader',
      'myStatus': 'accepted',
      'members': members,
      'createdAt': '2026-11-14T10:00:00.000Z',
      'updatedAt': '2026-11-14T10:00:00.000Z',
    };
  }

  http.Response _json(Map<String, dynamic> data, {int status = 200}) {
    return http.Response(
      jsonEncode(data),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}

Widget _buildApp(_PlannerBackend backend) {
  final client = ApiClient(
    httpClient: backend.client,
    baseUrl: 'http://test/api',
  );

  return MultiProvider(
    providers: [
      Provider<FriendsService>.value(value: FriendsService(client)),
      Provider<GroupsService>.value(value: GroupsService(client)),
      Provider<ToursService>.value(value: ToursService(client)),
    ],
    child: const MaterialApp(home: MainNavigationScreen()),
  );
}

void main() {
  testWidgets('Az alsó navigáció 3 fület mutat, a tervezés térképpel indul', (
    WidgetTester tester,
  ) async {
    final backend = _PlannerBackend();
    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    // Három fül: tervezés, közösség, profil.
    expect(find.text('Tervezés'), findsOneWidget);
    expect(find.text('Közösség'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Túra / Térkép'), findsNothing);

    // A tervezés első lépése csak térkép + úti cél keresősáv.
    expect(find.text('Hová szeretnél menni?'), findsOneWidget);
    expect(find.text('HONNAN INDULUNK?'), findsNothing);
    expect(find.text('TÚRA INDÍTÁSA'), findsNothing);
  });

  testWidgets('Úti cél után indulás választható, majd elindítható a túra', (
    WidgetTester tester,
  ) async {
    final backend = _PlannerBackend();
    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    // Úti cél keresése a felső keresősávban.
    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();

    // Megjelenik a honnan választó, alapból a jelenlegi tartózkodási hely.
    expect(find.text('HONNAN INDULUNK?'), findsOneWidget);
    expect(find.text('Jelenlegi tartózkodási hely'), findsOneWidget);
    expect(find.text('TOVÁBB A TERVEZÉSHEZ'), findsOneWidget);

    await tester.tap(find.text('TOVÁBB A TERVEZÉSHEZ'));
    await tester.pumpAndSettle();

    // Az útvonal a kiválasztott indulással és úti céllal jelenik meg.
    expect(find.text('KIVÁLASZTOTT ÚTVONAL'), findsOneWidget);
    expect(find.text('Jelenlegi hely ➔ Mátra ➔ Eger'), findsOneWidget);

    // AI elemzés, majd a túra indítása a tervezés végén.
    await tester.scrollUntilVisible(
      find.text('ÚTVONAL AI ELEMZÉSE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('ÚTVONAL AI ELEMZÉSE'));
    await tester.pumpAndSettle();
    expect(find.text('AI által javasolt megállók:'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('TÚRA INDÍTÁSA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('TÚRA INDÍTÁSA'));
    await tester.pumpAndSettle();

    // A túra a backendre is elmentődik, aktív státusszal.
    expect(backend.calls.contains('POST /api/tours'), isTrue);
    expect(backend.lastTourBody?['status'], 'active');
    expect(backend.lastTourBody?['destinationName'], 'Eger');

    // Túra közben eltűnik az alsó navigáció, a felső sáv az útvonalat mutatja.
    expect(find.text('Tervezés'), findsNothing);
    expect(find.text('69 km van hátra'), findsOneWidget);
    expect(find.text('Érkezés: 12:15 • 1 ó 10 perc'), findsOneWidget);
    expect(find.text('Jelenlegi hely'), findsWidgets);
    expect(find.text('Eger'), findsWidgets);

    // Az X gomb megerősítést kér; MÉGSE esetén a túra folytatódik.
    await tester.tap(find.byTooltip('Túra befejezése'));
    await tester.pumpAndSettle();
    expect(find.text('Biztosan be akarod fejezni a túrát?'), findsOneWidget);

    await tester.tap(find.text('MÉGSE'));
    await tester.pumpAndSettle();
    expect(find.text('69 km van hátra'), findsOneWidget);

    // Megerősítés után visszatér a tervezéshez (térkép + keresősáv).
    await tester.tap(find.byTooltip('Túra befejezése'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TÚRA BEFEJEZÉSE'));
    await tester.pumpAndSettle();

    expect(find.text('Tervezés'), findsOneWidget);
    expect(find.text('Hová szeretnél menni?'), findsOneWidget);
    expect(find.text('69 km van hátra'), findsNothing);
  });

  testWidgets('Az úti cél utólag is módosítható a keresősávból', (
    WidgetTester tester,
  ) async {
    final backend = _PlannerBackend();
    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();

    expect(find.text('Úti cél: Eger'), findsOneWidget);
    expect(find.text('HONNAN INDULUNK?'), findsOneWidget);

    // Újabb koppintás a keresősávra: a találatok a lap fölött jelennek meg.
    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();

    expect(find.text('TALÁLATOK'), findsOneWidget);
    expect(find.text('NÉPSZERŰ ÚTI CÉLOK'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Tokaj',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tokaj'));
    await tester.pumpAndSettle();

    // Az új úti cél jelenik meg a lapon, a korábbi eltűnik.
    expect(find.text('Úti cél: Tokaj'), findsOneWidget);
    expect(find.text('Úti cél: Eger'), findsNothing);
  });

  testWidgets('Kis kijelzőn is elfér a tervező, billentyűzettel együtt', (
    WidgetTester tester,
  ) async {
    // Tipikus telefonos kijelző.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final backend = _PlannerBackend();
    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();

    expect(find.text('HONNAN INDULUNK?'), findsOneWidget);

    // Billentyűzet: a lapnak ilyenkor is görgethetőnek kell maradnia.
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('originSearchField')),
      'Budapest',
    );
    await tester.pumpAndSettle();

    // Billentyűzet elrejtése, majd tovább a tervezésre.
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.tap(find.text('TOVÁBB A TERVEZÉSHEZ'));
    await tester.pumpAndSettle();

    expect(find.text('KIVÁLASZTOTT ÚTVONAL'), findsOneWidget);
    expect(find.text('Budapest ➔ Mátra ➔ Eger'), findsOneWidget);
  });

  testWidgets('A túra mentése a kiválasztott barátokkal a backendre kerül', (
    WidgetTester tester,
  ) async {
    final backend = _PlannerBackend();
    await tester.pumpWidget(_buildApp(backend));
    await tester.pumpAndSettle();

    // Úti cél és indulás, majd AI elemzés.
    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TOVÁBB A TERVEZÉSHEZ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ÚTVONAL AI ELEMZÉSE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('ÚTVONAL AI ELEMZÉSE'));
    await tester.pumpAndSettle();

    // A meghívható barátok a backendről töltődnek be.
    await tester.scrollUntilVisible(
      find.text('TÚRA MENTÉSE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('inviteFriend_f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inviteFriend_f1')));
    await tester.pumpAndSettle();

    expect(find.text('Kiválasztva: 1 barát, 0 csoport'), findsOneWidget);

    // Mentés (nem indítás): draft státusszal, a kiválasztott baráttal.
    await tester.ensureVisible(find.text('TÚRA MENTÉSE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TÚRA MENTÉSE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(backend.calls.contains('POST /api/tours'), isTrue);
    expect(backend.lastTourBody?['status'], 'draft');
    expect(
      backend.lastTourBody?['inviteUserIds'] as List<dynamic>,
      contains('f1'),
    );
    expect(find.textContaining('Túra elmentve'), findsOneWidget);

    // Mentés után a tervezőn maradunk (a túra nem indul el).
    expect(find.text('Tervezés'), findsOneWidget);
    expect(backend.tours, hasLength(1));
  });
}
