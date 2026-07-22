import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/auth_controller.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

class EmpApp extends StatelessWidget {
  const EmpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..bootstrap(),
      child: MaterialApp(
        title: 'Emp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _Gate(),
      ),
    );
  }
}

/// Routes between login and the signed-in shell based on auth state.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.initializing:
        return const Scaffold(
            body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        final user = auth.user;
        if (user == null) {
          // Signed in but profile lookup failed — offer a retry via logout.
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Signed in, but your profile could not load.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.read<AuthController>().logout(),
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          );
        }
        return HomeShell(user: user);
    }
  }
}
