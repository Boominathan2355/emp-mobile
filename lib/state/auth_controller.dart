import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

enum AuthStatus { initializing, signedOut, signedIn }

/// Owns auth state over the stateless JWT backend. Restores a stored session on
/// launch; any 401 anywhere in the app drops back to signed-out.
class AuthController extends ChangeNotifier {
  AuthController() {
    ApiClient.instance.onUnauthorized = _onUnauthorized;
  }

  final _auth = AuthService();
  final _profiles = ProfileService();

  AuthStatus status = AuthStatus.initializing;
  AppUser? user;
  String? error;

  Future<void> bootstrap() async {
    await Session.instance.load();
    final username = await _auth.restore();
    if (username == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    await _loadProfile(username);
  }

  Future<bool> login(String identifier, String password) async {
    error = null;
    notifyListeners();
    try {
      final username = await _auth.login(identifier, password);
      await _loadProfile(username);
      return true;
    } on ApiException catch (e) {
      // 401 is intentionally generic so the form can't enumerate accounts.
      error = e.status == 401 ? 'Invalid credentials' : e.message;
      status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Could not reach the server. Check your connection.';
      status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadProfile(String username) async {
    try {
      user = await _profiles.currentUser(username);
    } catch (_) {
      // Profile lookup is best-effort; keep the session even if it fails.
      user = null;
    }
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  void _onUnauthorized() {
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
