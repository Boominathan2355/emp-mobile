import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../state/duty_controller.dart';
import 'duty_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'widgets/location_warning_banner.dart';

/// The signed-in shell: Duty / History / Profile tabs (matches the screenshots).
///
/// Owns the [DutyController] for the whole session — the tabs share one duty
/// state, and the location warning sits above the tab content so the countdown
/// is visible from History and Profile too, not just Duty.
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
      // isActive gates the Duty tab's pre-check-in prompt: every tab stays
      // built inside the IndexedStack, and that dialog must not pop up over
      // History or Profile.
      DutyScreen(isActive: _index == 0),
      const HistoryScreen(),
      ProfileScreen(user: widget.user),
    ];
    return ChangeNotifierProvider(
      create: (_) => DutyController(widget.user),
      child: Scaffold(
        body: Column(
          children: [
            const LocationWarningBanner(),
            Expanded(
              child: IndexedStack(index: _index, children: tabs),
            ),
          ],
        ),
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
      ),
    );
  }
}
