import 'package:shared_preferences/shared_preferences.dart';

/// A JWT token tárolásának absztrakciója (tesztben helyettesíthető).
abstract class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Tartós token tárolás a SharedPreferences-ben.
///
/// Megjegyzés: ez a szakdolgozat prototípusához elegendő; éles alkalmazásban
/// érdemes a tokent `flutter_secure_storage`-ba (Keystore/Keychain) tenni.
class SharedPrefsTokenStorage implements TokenStorage {
  static const String _tokenKey = 'auth_token';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  @override
  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
