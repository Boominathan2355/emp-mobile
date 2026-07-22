import 'package:geolocator/geolocator.dart';

import '../data/api_client.dart';
import '../data/models.dart';

/// Reports device position to `/api/tracking/ingest` (LocationController).
/// This is the app's role as a device reporter — the web frontend only reads
/// `/locations` and `/route`. The ingest contract (IngestPingRequest):
///   { employeeId, name, role?, avatarUrl?, status, lat, lng, speed?, recordedAt? }
class TrackingService {
  final _api = ApiClient.instance;

  /// Ensures location services + permission are granted. Throws a readable
  /// message on refusal so the Duty screen can surface it.
  Future<void> ensureLocationReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled. Enable GPS to check in.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw StateError('Location permission denied. Allow it to check in.');
    }
  }

  Future<Position> currentPosition() => Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

  /// Sends one GPS report with the given presence status.
  Future<void> ingest({
    required AppUser user,
    required PresenceStatus status,
    required Position pos,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/api/tracking/ingest',
      body: {
        'employeeId': user.code.isNotEmpty ? user.code : user.id.toString(),
        'name': user.name.isNotEmpty ? user.name : user.username,
        'role': user.role,
        'avatarUrl': user.photoUrl,
        'status': status.wire,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed >= 0 ? pos.speed * 3.6 : null, // m/s -> km/h
        // recordedAt omitted -> server stamps "now"
      },
    );
  }
}
