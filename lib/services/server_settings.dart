import 'package:shared_preferences/shared_preferences.dart';

/// Az API szerver címének tárolása a SharedPreferences-ben.
///
/// A cím a bejelentkező képernyőn futásidőben módosítható, így fizikai
/// eszközön nem kell újrafordítani az alkalmazást, ha más gépen fut a backend.
class ServerSettings {
  static const String _baseUrlKey = 'api_base_url';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey);
  }

  Future<void> write(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
  }
}
