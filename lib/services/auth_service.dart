import 'dart:convert';

import '../data/api_client.dart';
import '../data/session.dart';

/// Login / logout against emp-core-service. `identifier` may be the username
/// OR the 10-digit mobile number. Both credential fields are Base64-encoded by
/// the client and decoded server-side (obfuscation, not encryption — transport
/// security comes from HTTPS). See api-contract.md §3.
class AuthService {
  final _api = ApiClient.instance;

  String _b64(String v) => base64.encode(utf8.encode(v));

  /// Exchanges credentials for a JWT and stores it. Returns the login handle
  /// (username) resolved from `/api/auth/me`. Throws [ApiException] on 401.
  Future<String> login(String identifier, String password) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/auth/login',
      body: {
        'identifier': _b64(identifier.trim()),
        'password': _b64(password),
      },
    );
    await Session.instance.setToken(res['token'] as String);
    try {
      final me = await _api.get<Map<String, dynamic>>('/api/auth/me');
      final username = me['username'] as String;
      await Session.instance.setUsername(username);
      return username;
    } catch (e) {
      await Session.instance.clear();
      rethrow;
    }
  }

  /// Restores a stored session by validating the token via `/api/auth/me`.
  /// Returns the username, or null when there's no valid token.
  Future<String?> restore() async {
    if (Session.instance.token == null) return null;
    try {
      final me = await _api.get<Map<String, dynamic>>('/api/auth/me');
      final username = me['username'] as String;
      await Session.instance.setUsername(username);
      return username;
    } catch (_) {
      await Session.instance.clear();
      return null;
    }
  }

  /// Revokes the token server-side, then drops it locally regardless.
  Future<void> logout() async {
    try {
      await _api.post<void>('/api/auth/logout');
    } catch (_) {
      // best-effort revoke; local clear is what matters
    } finally {
      await Session.instance.clear();
    }
  }
}
