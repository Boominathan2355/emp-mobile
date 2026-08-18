import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../state/duty_controller.dart';

/// The in-app half of the location-off warning.
///
/// Lives in the signed-in shell rather than the Duty screen so it stays visible
/// on every tab — someone browsing History has exactly as much need to know the
/// countdown is running. The system notification carries the same message for
/// when the app is backgrounded; both render the countdown through
/// [NotificationService.formatCountdown] so they never drift apart.
///
/// Renders nothing unless the countdown is live or an automatic check-out is
/// waiting to be acknowledged.
class LocationWarningBanner extends StatelessWidget {
  const LocationWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyController>();

    if (duty.locationLost) {
      return _Banner(
        color: AppTheme.warning,
        icon: Icons.location_off,
        title: 'Turn on location',
        message: 'Location is off. Turn it on within '
            '${NotificationService.formatCountdown(duty.graceRemaining)} or you '
            'will be taken off duty automatically.',
        actionLabel: 'Turn on',
        onAction: () => context.read<DutyController>().openLocationSettings(),
      );
    }

    if (duty.autoCheckedOut) {
      return _Banner(
        color: AppTheme.danger,
        icon: Icons.logout,
        title: 'You were taken off duty',
        message: 'Location stayed off for more than '
            '${NotificationService.formatMinutes(AppConfig.locationGrace)}, so '
            'your duty was ended automatically. Check in again once location is on.',
        actionLabel: 'Dismiss',
        onAction: () =>
            context.read<DutyController>().acknowledgeAutoCheckOut(),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: 0.16), AppTheme.cardAlt),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: color),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
