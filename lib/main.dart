import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'screens/auth/auth_gate.dart';
import 'services/api_client.dart';
import 'services/friends_service.dart';
import 'services/groups_service.dart';
import 'services/http_auth_api.dart';
import 'services/server_settings.dart';
import 'services/token_storage.dart';
import 'state/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A login képernyőn mentett szerver cím (pl. USB-s telefon + adb reverse),
  // ha nincs, a fordítási idejű alapértelmezés (emulátor: 10.0.2.2) él.
  final savedBaseUrl = await ServerSettings().read();
  final apiClient = ApiClient(
    baseUrl: (savedBaseUrl == null
            ? null
            : ApiConfig.normalizeBaseUrl(savedBaseUrl)) ??
        ApiConfig.baseUrl,
  );
  final authController = AuthController(
    api: HttpAuthApi(apiClient),
    storage: SharedPrefsTokenStorage(),
  );

  runApp(
    MotorcycleConvoyApp(
      authController: authController,
      friendsService: FriendsService(apiClient),
      groupsService: GroupsService(apiClient),
      apiClient: apiClient,
    ),
  );
}

class MotorcycleConvoyApp extends StatelessWidget {
  const MotorcycleConvoyApp({
    super.key,
    required this.authController,
    required this.friendsService,
    required this.groupsService,
    required this.apiClient,
  });

  final AuthController authController;
  final FriendsService friendsService;
  final GroupsService groupsService;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        Provider<FriendsService>.value(value: friendsService),
        Provider<GroupsService>.value(value: groupsService),
        Provider<ApiClient>.value(value: apiClient),
      ],
      child: MaterialApp(
        title: 'Motoros Konvoj',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          colorScheme: const ColorScheme.light(
            primary:
                Colors.amber, // Jól látható, motoros témához illő sárga/narancs
            onPrimary: Colors.black,
            secondary: Colors.amberAccent,
            onSecondary: Colors.black,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        // Bejelentkezés nélkül a login képernyő, utána a fő navigáció.
        home: const AuthGate(),
      ),
    );
  }
}
