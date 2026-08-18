import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../state/duty_controller.dart';
import 'widgets/hold_button.dart';

/// Duty tab: off-duty -> hold to check in -> verifying (internet/location) ->
/// on-duty -> hold to check out. Matches the screenshots.
class DutyScreen extends StatelessWidget {
  const DutyScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DutyController(user),
      child: const _DutyBody(),
    );
  }
}

class _DutyBody extends StatelessWidget {
  const _DutyBody();

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                duty.onDuty ? "You're on duty" : "You're off duty",
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 40),
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
                      onComplete: () => context.read<DutyController>().checkOut(),
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
                      onComplete: () => context.read<DutyController>().checkIn(),
                    ),
                    const SizedBox(height: 20),
                    const Text('Hold for 5s to check in',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              if (duty.step == VerifyStep.failed && duty.error != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(duty.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFE5484D))),
                ),
                if (duty.error!.contains('App Settings') ||
                    duty.error!.contains('permanently denied')) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Geolocator.openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open App Settings'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
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
