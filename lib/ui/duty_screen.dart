import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../state/duty_controller.dart';
import 'widgets/hold_button.dart';
import 'widgets/preflight_dialog.dart';

/// Duty tab: off-duty -> hold to check in -> verifying (internet/location) ->
/// on-duty -> hold to check out. Matches the screenshots.
///
/// Reads its [DutyController] from an ancestor (HomeShell owns it) so the
/// location warning banner in the shell and this screen share one duty state.
class DutyScreen extends StatelessWidget {
  const DutyScreen({super.key, this.isActive = true});

  /// Whether this is the tab the user is looking at. HomeShell keeps every tab
  /// alive in an IndexedStack, and the pre-check-in prompt must not pop up over
  /// History or Profile.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  duty.onDuty ? "You're on duty" : "You're off duty",
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    duty.onDuty
                        ? 'Location tracking is on and shared with your organization.'
                        : 'Check in to start sharing your location with your organization.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 14, height: 1.4),
                  ),
                ),
                if (duty.locationLost) ...[
                  const SizedBox(height: 24),
                  _GraceCountdown(remaining: duty.graceRemaining),
                ],
                const SizedBox(height: 40),
                if (duty.verifying)
                  _Verifying(duty: duty)
                else if (duty.onDuty)
                  Column(
                    children: [
                      HoldButton(
                        label: 'Check Out',
                        icon: Icons.logout,
                        color: AppTheme.danger,
                        hold: AppConfig.holdToConfirm,
                        onComplete: () =>
                            context.read<DutyController>().checkOut(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Hold for 5s to check out',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  )
                else
                  _CheckInGate(isActive: isActive),
                if (duty.step == VerifyStep.failed && duty.error != null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(duty.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.danger)),
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
      ),
    );
  }
}

/// The off-duty control. Check In only appears once internet *and* location are
/// confirmed on; otherwise the user gets the prompt telling them what to fix.
///
/// The prompt opens by itself the first time the prerequisites are found
/// missing, and re-arms whenever they go from ready back to not-ready — so a
/// user who dismisses it is not nagged every frame, but is still prompted again
/// if they switch something off later.
class _CheckInGate extends StatefulWidget {
  const _CheckInGate({required this.isActive});
  final bool isActive;

  @override
  State<_CheckInGate> createState() => _CheckInGateState();
}

class _CheckInGateState extends State<_CheckInGate> {
  bool _promptShown = false;

  void _maybePrompt(DutyController duty) {
    if (!duty.preflightChecked || duty.preflightReady) {
      _promptShown = false; // re-arm for the next time something is switched off
      return;
    }
    if (_promptShown || !widget.isActive) return;
    _promptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showPreflightDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyController>();
    _maybePrompt(duty);

    if (!duty.preflightChecked) {
      return const Column(
        children: [
          SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 16),
          Text('Checking internet and location…',
              style: TextStyle(color: AppTheme.textMuted)),
        ],
      );
    }

    if (duty.preflightReady) {
      return Column(
        children: [
          HoldButton(
            label: 'Check In',
            icon: Icons.login,
            hold: AppConfig.holdToConfirm,
            onComplete: () => context.read<DutyController>().checkIn(),
          ),
          const SizedBox(height: 20),
          const Text('Hold for 5s to check in',
              style: TextStyle(color: AppTheme.textMuted)),
        ],
      );
    }

    return _NotReady(
      networkReady: duty.networkReady == true,
      locationReady: duty.locationReady == true,
    );
  }
}

/// Replaces the Check In button while a prerequisite is missing. Deliberately
/// not a disabled Check In button: the user's next action is to fix something,
/// so that is what the control does.
class _NotReady extends StatelessWidget {
  const _NotReady({required this.networkReady, required this.locationReady});
  final bool networkReady;
  final bool locationReady;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!locationReady) 'location',
      if (!networkReady) 'mobile data / Wi-Fi',
    ].join(' and ');

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                AppTheme.warning.withValues(alpha: 0.12), AppTheme.cardAlt),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.45)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.warning, size: 28),
              const SizedBox(height: 10),
              const Text(
                "Can't check in yet",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Turn on $missing to check in.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => showPreflightDialog(context),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
                icon: const Icon(Icons.tune),
                label: const Text('Fix now'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => context.read<DutyController>().refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Re-check'),
        ),
      ],
    );
  }
}

/// The on-screen countdown while location is off and duty is about to end.
/// Mirrors the system notification the controller posts in parallel.
class _GraceCountdown extends StatelessWidget {
  const _GraceCountdown({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
            AppTheme.warning.withValues(alpha: 0.14), AppTheme.cardAlt),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, color: AppTheme.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Location is off',
                style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            NotificationService.formatCountdown(remaining),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Turn location back on before this reaches 0:00,\n'
            'or you will be taken off duty automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                context.read<DutyController>().openLocationSettings(),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
            icon: const Icon(Icons.my_location),
            label: const Text('Turn on location'),
          ),
        ],
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
