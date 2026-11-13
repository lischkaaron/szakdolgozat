/// A backend REST API elérési beállításai.
///
/// Az alapérték az Android emulátor számára a 10.0.2.2 (a hosztgép loopbackje).
/// Fizikai eszközön a számítógép helyi IP-címét kell megadni, pl.:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.42:3000/api
///
/// iOS szimulátoron / asztali gépen: http://localhost:3000/api
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  /// A megadott szerver cím normalizálása.
  ///
  /// - levágja a szóközöket,
  /// - `http://` sémát tesz elé, ha nincs,
  /// - eltávolítja a záró `/` karaktereket,
  /// - hozzáfűzi az `/api` előtagot, ha a cím nem arra végződik.
  ///
  /// `null`-t ad vissza, ha a cím értelmezhetetlen (nincs hosztnév).
  static String? normalizeBaseUrl(String raw) {
    var value = raw.trim();

    if (value.isEmpty) {
      return null;
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    final uri = Uri.tryParse(value);

    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    if (!value.endsWith('/api')) {
      value = '$value/api';
    }

    return value;
  }
}
