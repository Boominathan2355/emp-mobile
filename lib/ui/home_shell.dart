import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'duty_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

/// The signed-in shell: Duty / History / Profile tabs (matches the screenshots).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final AppUser user;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      DutyScreen(user: widget.user),
      const HistoryScreen(),
      ProfileScreen(user: widget.user),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          backgroundColor: AppTheme.cardAlt,
          indicatorColor: AppTheme.card,
          labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.access_time), label: 'Duty'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
