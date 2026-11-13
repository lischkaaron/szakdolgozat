import '../models/auth_session.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'auth_api.dart';

/// Az [AuthApi] REST implementációja a [ApiClient] segítségével.
class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._client);

  final ApiClient _client;

  @override
  void setToken(String? token) {
    _client.setToken(token);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    String? motorcycle,
  }) async {
    final trimmedMotorcycle = motorcycle?.trim();

    final data = await _client.post(
      '/auth/register',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'displayName': displayName.trim(),
        if (trimmedMotorcycle != null && trimmedMotorcycle.isNotEmpty)
          'motorcycle': trimmedMotorcycle,
      },
    );

    return AuthSession.fromJson(data);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/auth/login',
      body: <String, dynamic>{'email': email.trim(), 'password': password},
    );

    return AuthSession.fromJson(data);
  }

  @override
  Future<User> fetchMe() async {
    final data = await _client.get('/users/me');
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<User> updateProfile({String? displayName, String? motorcycle}) async {
    final body = <String, dynamic>{};

    if (displayName != null) {
      body['displayName'] = displayName;
    }

    if (motorcycle != null) {
      body['motorcycle'] = motorcycle;
    }

    final data = await _client.patch('/users/me', body: body);

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }
}
