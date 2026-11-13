import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// A backend által visszaadott hiba (vagy hálózati hiba) egységes kivétele.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Egyszerű JSON REST kliens a Motoros Konvoj backendhez.
///
/// A tokent a [setToken] állítja be; ha be van állítva, minden kérés
/// `Authorization: Bearer <token>` fejlécet kap.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;

  /// Az aktuálisan használt API gyökér URL (pl. `http://localhost:3000/api`).
  /// A bejelentkező képernyő beállítása ezt futásidőben átírhatja.
  String baseUrl;

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    try {
      final http.Response response;

      if (method == 'GET') {
        response = await _http
            .get(uri, headers: headers)
            .timeout(ApiConfig.requestTimeout);
      } else if (method == 'POST') {
        response = await _http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(ApiConfig.requestTimeout);
      } else if (method == 'PATCH') {
        response = await _http
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(ApiConfig.requestTimeout);
      } else if (method == 'DELETE') {
        response = await _http
            .delete(uri, headers: headers)
            .timeout(ApiConfig.requestTimeout);
      } else {
        throw ApiException('Nem támogatott HTTP metódus: $method');
      }

      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'A szerver nem válaszolt időben '
        '(${ApiConfig.requestTimeout.inSeconds} másodperc). '
        'Fut a backend, és jó a szerver címe? '
        'A login képernyő alján a „Szerver” gombbal ellenőrizhető.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Nem érhető el a szerver (${error.message}). '
        'Ellenőrizd a szerver címét a login képernyő „Szerver” gombjával!',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = const <String, dynamic>{};

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } on FormatException {
        // Nem JSON válasz (pl. proxy hibaoldal) -> marad az üres map.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final error = data['error'];
    final message = error is Map && error['message'] is String
        ? error['message'] as String
        : 'Szerverhiba történt (HTTP ${response.statusCode}).';

    throw ApiException(message, statusCode: response.statusCode);
  }

  void close() {
    _http.close();
  }
}
