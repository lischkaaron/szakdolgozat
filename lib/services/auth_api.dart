import '../models/auth_session.dart';
import '../models/user.dart';

/// A hitelesítéssel kapcsolatos műveletek absztrakciója.
///
/// Az [AuthController] ezen a felületen keresztül beszél a backendbel, így
/// tesztben könnyen helyettesíthető hamis implementációval.
abstract class AuthApi {
  /// Beállítja (vagy törli) a kérésekhez használt JWT tokent.
  void setToken(String? token);

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    String? motorcycle,
  });

  Future<AuthSession> login({required String email, required String password});

  /// A token alapján lekéri a bejelentkezett felhasználót (`GET /users/me`).
  Future<User> fetchMe();

  Future<User> updateProfile({String? displayName, String? motorcycle});
}
