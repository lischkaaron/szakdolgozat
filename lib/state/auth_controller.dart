import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../services/token_storage.dart';

/// A bejelentkezési állapot lehetséges értékei.
enum AuthStatus {
  /// Még nem tudjuk (a mentett token ellenőrzése folyik).
  unknown,

  /// Nincs érvényes bejelentkezés -> login képernyő.
  unauthenticated,

  /// Bejelentkezett felhasználó -> fő alkalmazás.
  authenticated,
}

/// Az alkalmazás bejelentkezési állapotát kezelő [ChangeNotifier].
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.storage});

  final AuthApi api;
  final TokenStorage storage;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;
  bool _isBusy = false;
  bool _sessionChecked = false;

  AuthStatus get status => _status;

  User? get user => _user;

  String? get errorMessage => _errorMessage;

  bool get isBusy => _isBusy;

  /// Induláskor (egyszer) visszaállítja a mentett tokenből a munkamenetet.
  Future<void> restoreSession() async {
    if (_sessionChecked) {
      return;
    }
    _sessionChecked = true;

    final token = await storage.read();

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    api.setToken(token);

    try {
      _user = await api.fetchMe();
      _status = AuthStatus.authenticated;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        // Lejárt/érvénytelen token: töröljük.
        api.setToken(null);
        await storage.clear();
      } else {
        // Hálózati hiba: a token megmarad, de be kell jelentkezni újra.
        _errorMessage =
            'A munkamenet ellenőrzése nem sikerült: ${error.message}';
      }
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) {
    return _authenticate(() => api.login(email: email, password: password));
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? motorcycle,
  }) {
    return _authenticate(
      () => api.register(
        email: email,
        password: password,
        displayName: displayName,
        motorcycle: motorcycle,
      ),
    );
  }

  Future<bool> updateProfile({
    required String displayName,
    required String motorcycle,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await api.updateProfile(
        displayName: displayName,
        // Üres mező esetén a backend null-ra állítja a motort.
        motorcycle: motorcycle,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    api.setToken(null);
    await storage.clear();
    _user = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _authenticate(Future<AuthSession> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await action();

      api.setToken(session.token);
      await storage.write(session.token);

      _user = session.user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
