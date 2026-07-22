import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../services/profile_service.dart';
import '../state/auth_controller.dart';

/// Profile tab: avatar + details card + biometric toggle + logout.
/// Organization/Department are shown as placeholders — the backend user object
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
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.card,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Text(_initial(u.name),
                      style: const TextStyle(fontSize: 34))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Photo upload — POST /api/users/{id}/photo')),
              ),
              child: const Text('Upload photo'),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _row('Name', u.name),
                _row('Employee code', u.code),
                _row('Email', u.email ?? '—'),
                _row('Mobile', u.mobile),
                _row('Role', u.role ?? '—'),
                _row('Organization', '—'), // not in UserResponse yet
                _row('Department', '—'), // not in UserResponse yet
                _row('Status', u.status.toLowerCase(), last: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
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

  Widget _row(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF3A3B40), width: 0.6)),
      ),
      child: Row(
        children: [
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
