import 'package:emp_mobile/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The countdown shown in the location-off banner and in the system
/// notification both render through these helpers, so a formatting change here
/// is the one place the two could silently drift apart.
void main() {
  group('formatCountdown', () {
    test('renders mm:ss with a zero-padded seconds field', () {
      expect(NotificationService.formatCountdown(const Duration(minutes: 2)),
          '2:00');
      expect(
          NotificationService.formatCountdown(
              const Duration(minutes: 1, seconds: 59)),
          '1:59');
      expect(NotificationService.formatCountdown(const Duration(seconds: 7)),
          '0:07');
      expect(NotificationService.formatCountdown(Duration.zero), '0:00');
    });

    test('clamps past-deadline values to 0:00 rather than showing "-0:01"', () {
      expect(NotificationService.formatCountdown(const Duration(seconds: -1)),
          '0:00');
    });
  });

  group('formatMinutes', () {
    test('singularises one minute', () {
      expect(NotificationService.formatMinutes(const Duration(minutes: 1)),
          '1 minute');
    });

    test('pluralises everything else', () {
      expect(NotificationService.formatMinutes(const Duration(minutes: 2)),
          '2 minutes');
    });
  });
}
