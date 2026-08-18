/// Service configuration. Mirrors the web app's `src/lib/config.ts`.
///
/// Both backends share the same origin behind the nginx gateway: everything
/// under `/api/**` goes to emp-core-service, and `/api/tracking/**` is routed
/// to emp-tracking-service. From the client's view it is one base URL.
///
/// Override at build/run time without editing this file:
///   flutter run --dart-define=CORE_BASE=http://192.168.1.20:8000
///
/// Defaults to `10.0.2.2:8000`, which is how the **Android emulator** reaches
/// `localhost` on the host machine. For a physical device, pass your machine's
/// LAN IP via --dart-define (the emulator alias won't resolve there).
class AppConfig {
  static const String coreBase = String.fromEnvironment(
    'CORE_BASE',
    defaultValue: 'https://emp-be-azew.onrender.com',
  );

  /// How often to report position to `/api/tracking/ingest` while on duty.
  static const Duration pingInterval = Duration(seconds: 15);

  /// Hold duration on the Check In / Check Out button (matches the UI copy).
  static const Duration holdToConfirm = Duration(seconds: 5);

  /// How long someone on duty may leave location services off before the app
  /// takes them off duty by itself. The countdown is surfaced both in-app and
  /// as a system notification so it is visible with the app backgrounded.
  static const Duration locationGrace = Duration(minutes: 2);

  /// How often the duty watchdog re-checks that location is still usable.
  /// The OS service-status stream covers the GPS toggle; this poll is what
  /// catches a *permission* revoked from the app-settings screen, which that
  /// stream never reports.
  static const Duration locationWatchdogInterval = Duration(seconds: 5);

  /// `statusReason` sent with the automatic off-duty ping so the roster can
  /// tell it apart from someone deliberately checking out. Kept in sync with
  /// emp-be `docs/tracking-fe-integration.md`.
  static const String reasonLocationDisabled = 'location-disabled';
}
