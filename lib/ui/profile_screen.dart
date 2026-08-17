import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../services/profile_service.dart';
import '../state/auth_controller.dart';

/// Profile tab: identity header card (avatar + name + role + status chip),
/// detail rows, biometric toggle, logout.
/// Organization/Department are placeholders — the backend user object
/// (UserResponse) has no such fields yet.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profiles = ProfileService();
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    Session.instance.biometricEnabled().then((v) {
      if (mounted) setState(() => _biometric = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final photo = _profiles.photoUrl(u);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.cardAlt,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? Text(_initial(u.name),
                          style: const TextStyle(fontSize: 34))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(u.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  u.role != null && u.role!.isNotEmpty ? u.role! : '—',
                  style:
                      const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                Text('EMP · ${u.code}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
                const SizedBox(height: 12),
                Chip(
                  backgroundColor: u.status == 'ACTIVE'
                      ? AppTheme.success.withValues(alpha: 0.15)
                      : AppTheme.cardAlt,
                  label: Text(
                    u.status == 'ACTIVE' ? 'Active' : u.status.toLowerCase(),
                    style: TextStyle(
                      color: u.status == 'ACTIVE'
                          ? AppTheme.success
                          : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Photo upload — POST /api/users/{id}/photo')),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Upload photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _row(Icons.mail_outline, 'Email', u.email ?? '—'),
                _row(Icons.phone_outlined, 'Mobile', u.mobile),
                _row(Icons.badge_outlined, 'Employee code', u.code),
                _row(Icons.business_outlined, 'Organization', '—'),
                _row(Icons.account_tree_outlined, 'Department', '—'),
                _row(Icons.fact_check_outlined, 'Username', u.username,
                    last: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              value: _biometric,
              activeThumbColor: AppTheme.accent,
              contentPadding: EdgeInsets.zero,
              title: const Text('Biometric login'),
              subtitle: const Text('Unlock with fingerprint / face',
                  style: TextStyle(color: AppTheme.textMuted)),
              onChanged: (v) async {
                await Session.instance.setBiometricEnabled(v);
                setState(() => _biometric = v);
              },
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: const BorderSide(color: AppTheme.accent),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => context.read<AuthController>().logout(),
            child: const Text('Logout', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  static String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  Widget _row(IconData icon, String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF3A3B40), width: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: AppTheme.textMuted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
