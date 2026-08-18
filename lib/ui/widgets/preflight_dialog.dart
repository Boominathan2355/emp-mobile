import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/duty_controller.dart';

/// The "turn location and data on" prompt shown before check-in.
///
/// Opened from the Duty screen when either prerequisite is missing. It watches
/// the same [DutyController] the screen does, so it ticks live: fix one of the
/// two and its row turns green, fix both and the dialog closes itself and the
/// Check In button appears behind it.
Future<void> showPreflightDialog(BuildContext context) {
  final duty = context.read<DutyController>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider<DutyController>.value(
      value: duty,
      child: const _PreflightDialog(),
    ),
  );
}

class _PreflightDialog extends StatelessWidget {
  const _PreflightDialog();

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyController>();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);

    // Everything is on now — get out of the user's way rather than making them
    // dismiss a dialog that no longer says anything. Guarded on isCurrent so a
    // late callback can never pop whatever route replaced this one.
    if (duty.preflightReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isCurrent) navigator.pop();
      });
    }

    return AlertDialog(
      backgroundColor: AppTheme.card,
      icon: const Icon(Icons.error_outline, color: AppTheme.warning, size: 32),
      title: const Text('Turn on location and data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Both are required before you can check in — your location is '
            'shared with your organization for the whole shift.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          _RequirementRow(
            ready: duty.locationReady,
            icon: Icons.location_on_outlined,
            label: 'Location',
            offLabel: 'Location services are off',
            onLabel: 'Location is on',
            actionLabel: 'Turn on',
            onAction: () => duty.openLocationSettings(),
          ),
          const SizedBox(height: 12),
          _RequirementRow(
            ready: duty.networkReady,
            icon: Icons.wifi,
            label: 'Internet',
            offLabel: 'Mobile data / Wi-Fi is off',
            onLabel: 'Internet is on',
            actionLabel: 'Turn on',
            onAction: () =>
                AppSettings.openAppSettings(type: AppSettingsType.wireless),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => duty.refresh(),
          child: const Text('Re-check'),
        ),
        TextButton(
          onPressed: () => navigator.pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.ready,
    required this.icon,
    required this.label,
    required this.offLabel,
    required this.onLabel,
    required this.actionLabel,
    required this.onAction,
  });

  /// Null while the first check is still in flight.
  final bool? ready;
  final IconData icon;
  final String label;
  final String offLabel;
  final String onLabel;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isReady = ready == true;
    final color = ready == null
        ? AppTheme.textMuted
        : (isReady ? AppTheme.success : AppTheme.warning);

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                ready == null ? 'Checking…' : (isReady ? onLabel : offLabel),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
        if (ready == false)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            child: Text(actionLabel),
          )
        else if (isReady)
          const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
      ],
    );
  }
}
