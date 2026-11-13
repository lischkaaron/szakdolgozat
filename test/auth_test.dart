import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_konvoj/models/auth_session.dart';
import 'package:moto_konvoj/models/user.dart';
import 'package:moto_konvoj/screens/auth/auth_gate.dart';
import 'package:moto_konvoj/services/api_client.dart';
import 'package:moto_konvoj/services/auth_api.dart';
import 'package:moto_konvoj/services/friends_service.dart';
import 'package:moto_konvoj/services/groups_service.dart';
import 'package:moto_konvoj/services/token_storage.dart';
import 'package:moto_konvoj/state/auth_controller.dart';

/// Memóriabeli token tároló a tesztekhez (SharedPreferences nélkül).
class _InMemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

/// Hamis auth API: nem hív hálózatot.
class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({this.loginError});

  static const User _defaultUser = User(
    id: 'u1',
    email: 'teszt@example.com',
    displayName: 'Teszt Elek',
  );

  final ApiException? loginError;
  String? token;

  @override
  void setToken(String? value) {
    token = value;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
    return const AuthSession(token: 'fake-token', user: _defaultUser);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    String? motorcycle,
  }) async {
    return AuthSession(
      token: 'fake-token',
      user: User(
        id: 'u2',
        email: email,
        displayName: displayName,
        motorcycle: motorcycle,
      ),
    );
  }

  @override
  Future<User> fetchMe() async => _defaultUser;

  @override
  Future<User> updateProfile({String? displayName, String? motorcycle}) async {
    return User(
      id: _defaultUser.id,
      email: _defaultUser.email,
      displayName: displayName ?? _defaultUser.displayName,
      motorcycle: motorcycle,
    );
  }
}

Widget _buildApp(AuthController controller, {ApiClient? apiClient}) {
  final client = apiClient ?? ApiClient();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: controller),
      Provider<FriendsService>.value(value: FriendsService(client)),
      Provider<GroupsService>.value(value: GroupsService(client)),
      Provider<ApiClient>.value(value: client),
    ],
    child: const MaterialApp(home: AuthGate()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Üres űrlappal küldve validációs hiba jelenik meg', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      api: _FakeAuthApi(),
      storage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(_buildApp(controller));
    await tester.pumpAndSettle();

    // A login képernyő jelenik meg (nincs mentett token).
    expect(find.text('Motoros Konvoj'), findsOneWidget);

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Add meg az e-mail címedet.'), findsOneWidget);
    expect(find.text('Add meg a jelszavadat.'), findsOneWidget);
    expect(controller.status, AuthStatus.unauthenticated);
  });

  testWidgets('Sikeres bejelentkezés után a fő navigáció jelenik meg', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      api: _FakeAuthApi(),
      storage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(_buildApp(controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'teszt@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'titkosJelszo123',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.status, AuthStatus.authenticated);
    expect(find.text('Tervezés'), findsOneWidget);
    expect(find.text('Közösség'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('Hibás bejelentkezésnél a backend hibaüzenete látszik', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      api: _FakeAuthApi(
        loginError: ApiException(
          'Hibás e-mail cím vagy jelszó.',
          statusCode: 401,
        ),
      ),
      storage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(_buildApp(controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'teszt@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'rosszJelszo',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Hibás e-mail cím vagy jelszó.'), findsOneWidget);
    expect(controller.status, AuthStatus.unauthenticated);
  });

  testWidgets('Regisztráció képernyő nyílik a linkre koppintva', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      api: _FakeAuthApi(),
      storage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(_buildApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nincs még fiókod? Regisztrálj'));
    await tester.pumpAndSettle();

    expect(find.text('Csatlakozz a konvojhoz'), findsOneWidget);
    expect(find.byKey(const Key('registerDisplayNameField')), findsOneWidget);
    expect(
      find.byKey(const Key('registerConfirmPasswordField')),
      findsOneWidget,
    );
  });

  testWidgets('A szerver cím mentése azonnal érvénybe lép', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      api: _FakeAuthApi(),
      storage: _InMemoryTokenStorage(),
    );
    final apiClient = ApiClient(baseUrl: 'http://10.0.2.2:3000/api');

    await tester.pumpWidget(_buildApp(controller, apiClient: apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('serverSettingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('API szerver címe'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('serverUrlField')),
      'http://localhost:3000',
    );
    await tester.tap(find.byKey(const Key('serverUrlSaveButton')));
    await tester.pumpAndSettle();

    // A megadott cím normalizálódik: http:// előtag és /api végződés.
    expect(apiClient.baseUrl, 'http://localhost:3000/api');
    expect(find.text('Szerver: http://localhost:3000/api'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_base_url'), 'http://localhost:3000/api');
  });
}
