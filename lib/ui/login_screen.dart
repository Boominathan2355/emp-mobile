import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/session.dart';
import '../state/auth_controller.dart';

/// Username-or-mobile + password login. Offers biometric unlock when the user
/// previously enabled it (a stored token still has to pass `/api/auth/me`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await context
        .read<AuthController>()
        .login(_identifier.text, _password.text);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _biometric() async {
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Emp',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) {
        // The stored token is validated by AuthController.bootstrap on relaunch;
        // here we just re-run the restore path.
        await context.read<AuthController>().bootstrap();
      }
    } catch (_) {/* cancelled / unavailable */}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.location_on, size: 56, color: AppTheme.accent),
                  const SizedBox(height: 12),
                  const Text('Emp',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Sign in to start your duty',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _identifier,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('Username or mobile', Icons.person_outline),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: _dec('Password', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Text(auth.error!,
                        style: const TextStyle(color: Color(0xFFE5484D))),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in', style: TextStyle(fontSize: 16)),
                  ),
                  FutureBuilder<List<bool>>(
                    future: Future.wait([
                      Session.instance.biometricEnabled(),
                      Session.instance.faceEnabled(),
                    ]),
                    builder: (context, snap) {
                      final hasBio = snap.data?[0] ?? false;
                      final hasFace = snap.data?[1] ?? false;
                      if ((hasBio || hasFace) && Session.instance.token != null) {
                        return TextButton.icon(
                          onPressed: _biometric,
                          icon: Icon(hasFace ? Icons.face : Icons.fingerprint),
                          label: Text(hasFace && hasBio
                              ? 'Unlock with Biometrics / Face ID'
                              : hasFace
                                  ? 'Unlock with Face ID'
                                  : 'Unlock with fingerprint'),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}
