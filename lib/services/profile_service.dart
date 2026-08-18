import '../core/config.dart';
import '../data/api_client.dart';
import '../data/models.dart';

/// Resolves the signed-in user's full profile. `/api/auth/me` only returns the
/// username + authorities, so we ask the users API for the caller's own record
/// to get the id/code/email/mobile/role/status shown on the Profile screen.
class ProfileService {
  final _api = ApiClient.instance;

  /// `GET /api/users/me` resolves the profile from the bearer token itself.
  /// The old approach — searching `/api/users?q=<username>` and matching the
  /// handle — could not see accounts the list deliberately hides (configadmin),
  /// and its "no exact match, take the first row" fallback risked showing
  /// somebody else's profile on a fuzzy hit.
  Future<AppUser> currentUser() async {
    final res = await _api.get<Map<String, dynamic>>('/api/users/me');
    return AppUser.fromJson(res);
  }

  /// Absolute URL for a user's photo bytes (`photoUrl` is a relative path).
  String? photoUrl(AppUser user) =>
      user.photoUrl == null ? null : '${AppConfig.coreBase}${user.photoUrl}';
}
