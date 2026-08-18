import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';

/// Reports device position to `/api/tracking/ingest` (LocationController).
/// This is the app's role as a device reporter — the web frontend only reads
/// `/locations` and `/route`. The ingest contract (IngestPingRequest):
///   { employeeId, name, role?, avatarUrl?, status, statusReason?, lat, lng,
///     speed?, recordedAt? }
class TrackingService {
  final _api = ApiClient.instance;

  /// Ensures location services + permission are granted. Throws a readable
  /// message on refusal so the Duty screen can surface it.
  Future<void> ensureLocationReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services (GPS) are disabled. Enable location to check in.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw StateError(
          'Location permission is permanently denied. Please enable it in App Settings.');
    }
    if (perm == LocationPermission.denied) {
      throw StateError('Location permission denied. Allow location access to check in.');
    }
  }

  /// A silent yes/no version of [ensureLocationReady] for the duty watchdog.
  ///
  /// Never prompts and never throws: while someone is on duty we only want to
  /// know whether we can still read a position, and a dialog fired from a
  /// background poll would be both useless and jarring.
  Future<bool> isLocationUsable() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final perm = await Geolocator.checkPermission();
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Fires whenever the OS location toggle flips. Covers the GPS switch only —
  /// a revoked *permission* never shows up here, which is why the controller
  /// also polls [isLocationUsable].
  Stream<ServiceStatus> get serviceStatusStream =>
      Geolocator.getServiceStatusStream();

  Future<Position> currentPosition() => Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

  /// Best-effort last fix from the OS cache. Used for the final `offline` ping
  /// when duty ends after location was switched off and no fresh fix exists.
  Future<Position?> lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Position updates for an active shift, running as an Android foreground
  /// service so the OS does not freeze the shift the moment the app is
  /// backgrounded. The service notification is the user-facing disclosure that
  /// tracking is on — see NotificationService.suppressOngoingOnAndroid for why
  /// the app does not post a second one alongside it.
  Stream<Position> dutyPositionStream() {
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          intervalDuration: AppConfig.pingInterval,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Location tracking is on',
            notificationText:
                'Your location is being shared with your organization while you are on duty.',
            notificationChannelName: 'Duty tracking',
            enableWakeLock: true,
            setOngoing: true,
            color: AppTheme.accent,
          ),
        ),
      );
    }
    if (Platform.isIOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        ),
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  /// Sends one GPS report with the given presence status.
  ///
  /// [statusReason] is echoed back on `/api/tracking/locations` so the roster
  /// can distinguish an automatic off-duty ping from a deliberate check-out;
  /// leave it null for routine pings.
  Future<void> ingest({
    required AppUser user,
    required PresenceStatus status,
    required Position pos,
    String? statusReason,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/api/tracking/ingest',
      body: {
        'employeeId': user.code.isNotEmpty ? user.code : user.id.toString(),
        'name': user.name.isNotEmpty ? user.name : user.username,
        'role': user.role,
        'avatarUrl': user.photoUrl,
        'status': status.wire,
        if (statusReason != null) 'statusReason': statusReason,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed >= 0 ? pos.speed * 3.6 : null, // m/s -> km/h
        // recordedAt omitted -> server stamps "now"
      },
    );
  }
}
