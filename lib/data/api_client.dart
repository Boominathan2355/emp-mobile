import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'session.dart';

/// Thrown for any non-2xx response. `message` always comes from the server's
/// `{ "error": ... }` body when present, else the status text — never
/// FE-authored copy (same policy as the web app's http.ts).
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.body});
  final int status;
  final String message;
  final Object? body;
  @override
  String toString() => 'ApiException($status): $message';
}

/// JSON REST client for the stateless JWT backend. Attaches the bearer token
/// and (on mutations) the actor `X-Username` header; a 401 clears the session
/// and invokes [onUnauthorized] so the app returns to the login screen.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Registered by the auth layer; fired on any 401.
  void Function()? onUnauthorized;

  Uri _uri(String path) => Uri.parse('${AppConfig.coreBase}$path');

  Map<String, String> _headers(String method) {
    final token = Session.instance.token;
    final actor = method == 'GET' ? null : Session.instance.username;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (actor != null) 'X-Username': actor,
    };
  }

  Future<T> get<T>(String path) => _send<T>('GET', path);
  Future<T> post<T>(String path, {Object? body}) =>
      _send<T>('POST', path, body: body);

  Future<T> _send<T>(String method, String path, {Object? body}) async {
    late http.Response res;
    final uri = _uri(path);
    final headers = _headers(method);
    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: jsonEncode(body));
        break;
      default:
        res = await http.get(uri, headers: headers);
    }
    return _handle<T>(res, '$method $path');
  }

  T _handle<T>(http.Response res, String endpoint) {
    if (res.statusCode == 401) {
      Session.instance.clear();
      onUnauthorized?.call();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      Object? parsed;
      try {
        parsed = jsonDecode(res.body);
      } catch (_) {}
      final msg = (parsed is Map && parsed['error'] is String)
          ? parsed['error'] as String
          : (res.reasonPhrase ?? 'HTTP ${res.statusCode}');
      throw ApiException(res.statusCode, msg, body: parsed);
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null as T;
    return jsonDecode(res.body) as T;
  }
}
