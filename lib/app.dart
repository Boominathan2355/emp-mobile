import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'state/auth_controller.dart';
import 'state/duty_controller.dart';
import 'ui/duty_screen.dart';
import 'ui/history_screen.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';
import 'ui/profile_screen.dart';

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
        routes: {
          '/login': (_) => const LoginScreen(),
          '/history': (_) => const HistoryScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/home':
              return MaterialPageRoute(
                builder: (ctx) {
                  final user = (settings.arguments as AppUser?) ??
                      ctx.read<AuthController>().user;
                  if (user == null) return const LoginScreen();
                  return HomeShell(user: user);
                },
              );
            case '/duty':
              // Standalone route (deep link / direct push): HomeShell normally
              // owns the DutyController, so this entry point brings its own.
              return MaterialPageRoute(
                builder: (ctx) {
                  final user = (settings.arguments as AppUser?) ??
                      ctx.read<AuthController>().user;
                  if (user == null) return const LoginScreen();
                  return ChangeNotifierProvider(
                    create: (_) => DutyController(user),
                    child: const DutyScreen(),
                  );
                },
              );
            case '/profile':
              return MaterialPageRoute(
                builder: (ctx) {
                  final user = (settings.arguments as AppUser?) ??
                      ctx.read<AuthController>().user;
                  if (user == null) return const LoginScreen();
                  return ProfileScreen(user: user);
                },
              );
          }
          return null;
        },
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
        // _loadProfile always leaves a profile behind (a placeholder when the
        // lookup fails), so signing in goes straight to the Duty tab.
        final user = auth.user;
        if (user == null) return const LoginScreen();
        return HomeShell(user: user);
    }
  }
}
