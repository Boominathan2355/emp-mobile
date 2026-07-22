import '../core/config.dart';
import '../data/api_client.dart';
import '../data/models.dart';

/// Resolves the signed-in user's full profile. `/api/auth/me` only returns the
/// username + authorities, so we look the user up in the users list by that
/// handle to get the id/code/email/mobile/role/status shown on the Profile
/// screen (api-contract.md §2a).
class ProfileService {
  final _api = ApiClient.instance;

  Future<AppUser> currentUser(String username) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/users?q=${Uri.encodeQueryComponent(username)}&size=20',
    );
    final content = (res['content'] as List).cast<Map<String, dynamic>>();
    // `q` is a fuzzy search across several fields — pick the exact handle match.
    final match = content.firstWhere(
      (u) => u['username'] == username,
      orElse: () => content.isNotEmpty
          ? content.first
          : (throw ApiException(404, 'User not found')),
    );
    return AppUser.fromJson(match);
  }

  /// Absolute URL for a user's photo bytes (`photoUrl` is a relative path).
  String? photoUrl(AppUser user) =>
      user.photoUrl == null ? null : '${AppConfig.coreBase}${user.photoUrl}';
}
