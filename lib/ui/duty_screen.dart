import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../state/duty_controller.dart';
import 'widgets/hold_button.dart';

/// Home tab: greeting header, live duty-status card, today's stats
/// (check-in time, hours, distance), then hold-to-check-in/out with the
/// verify steps. Off-duty -> hold to check in -> verifying -> on-duty ->
/// hold to check out.
class DutyScreen extends StatelessWidget {
  const DutyScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DutyController(user),
      child: _DutyBody(user: user),
    );
  }
}

class _DutyBody extends StatelessWidget {
  const _DutyBody({required this.user});
  final AppUser user;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _firstName(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'there' : first;
  }

  static String _clock() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}';
  }

  static String _date() {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }

  static String _hours(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static String _checkInLabel(DateTime? t) {
    if (t == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyController>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting,
                          style: const TextStyle(
                              fontSize: 16, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        _firstName(user.name),
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.card,
                  child: Text(
                    _initial(user.name),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_date(),
                style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 24),

            _StatusCard(
              onDuty: duty.onDuty,
              clock: _clock(),
              dateLabel: _date(),
            ),
            const SizedBox(height: 16),

            _StatsCard(
              checkIn: _checkInLabel(duty.dutySince),
              hours: _hours(duty.sessionDuration),
              distanceKm: duty.todayDistanceKm,
            ),
            const SizedBox(height: 28),

            if (duty.verifying)
              _Verifying(duty: duty)
            else if (duty.onDuty)
              Column(
                children: [
                  HoldButton(
                    label: 'Check Out',
                    icon: Icons.logout,
                    color: const Color(0xFFE5484D),
                    hold: const Duration(seconds: 5),
                    onComplete: () =>
                        context.read<DutyController>().checkOut(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Hold for 5s to check out',
                      style: TextStyle(color: AppTheme.textMuted)),
                ],
              )
            else
              Column(
                children: [
                  HoldButton(
                    label: 'Check In',
                    icon: Icons.login,
                    hold: const Duration(seconds: 5),
                    onComplete: () =>
                        context.read<DutyController>().checkIn(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Hold for 5s to check in',
                      style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),

            if (duty.step == VerifyStep.failed && duty.error != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  duty.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE5484D)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.onDuty,
    required this.clock,
    required this.dateLabel,
  });

  final bool onDuty;
  final String clock;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onDuty ? AppTheme.success : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                onDuty ? 'ON DUTY' : 'OFF DUTY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: onDuty ? AppTheme.success : AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(clock,
              style: const TextStyle(
                  fontSize: 44, fontWeight: FontWeight.w300)),
          const SizedBox(height: 2),
          Text(dateLabel,
              style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.checkIn,
    required this.hours,
    required this.distanceKm,
  });

  final String checkIn;
  final String hours;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.cardAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(value: checkIn, label: 'Check-in'),
          ),
          _divider(),
          Expanded(
            child: _Stat(value: hours, label: 'On duty'),
          ),
          _divider(),
          Expanded(
            child: _Stat(
                value: distanceKm.toStringAsFixed(1), label: 'km today'),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: const Color(0xFF3A3B40),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }
}

class _Verifying extends StatelessWidget {
  const _Verifying({required this.duty});
  final DutyController duty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accent,
            disabledBackgroundColor: AppTheme.accent,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Verifying…', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _CheckRow(
          done: duty.internetOk,
          active: duty.step == VerifyStep.internet,
          label: duty.internetOk ? 'Internet OK' : 'Checking Internet…',
        ),
        const SizedBox(height: 12),
        _CheckRow(
          done: duty.locationOk,
          active: duty.step == VerifyStep.location,
          label: duty.locationOk ? 'Location OK' : 'Checking Location…',
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(
      {required this.done, required this.active, required this.label});
  final bool done;
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    if (done) {
      leading = const Icon(Icons.check_circle, color: AppTheme.success);
    } else if (active) {
      leading = const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
      );
    } else {
      leading = const Icon(Icons.radio_button_unchecked,
          color: AppTheme.textMuted);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontSize: 18,
                color: done ? AppTheme.success : AppTheme.textPrimary)),
      ],
    );
  }
}
