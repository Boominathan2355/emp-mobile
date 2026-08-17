/// Wire models mirroring the backend DTOs (see emp_server/docs/api-contract.md
/// and tracking-fe-integration.md). Field shapes match the JSON exactly.
library;

/// Presence values reported to `/api/tracking/ingest`. Wire strings are fixed.
enum PresenceStatus {
  online('online'),
  onDuty('on-duty'),
  offline('offline');

  const PresenceStatus(this.wire);
  final String wire;
}

/// A user profile, as returned by `GET /api/users/{id}` (UserResponse).
/// Note: the backend object has no organization/department fields yet — the
/// Profile screen shows placeholders for those (see ProfileService).
class AppUser {
  const AppUser({
    required this.id,
    required this.code,
    required this.username,
    required this.name,
    this.email,
    required this.mobile,
    this.photoUrl,
    this.role,
    required this.status,
  });

  final int id;
  final String code;
  final String username;
  final String name;
  final String? email;
  final String mobile;
  final String? photoUrl;

  /// Id of the dynamic role (a UUID string), or null when unassigned.
  final String? role;

  /// "ACTIVE" | "INACTIVE".
  final String status;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        code: j['code'] as String? ?? '',
        username: j['username'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String?,
        mobile: j['mobile'] as String? ?? '',
        photoUrl: j['photoUrl'] as String?,
        role: j['role'] as String?,
        status: j['status'] as String? ?? 'ACTIVE',
      );
}

/// One day's attendance row, as returned by `GET /api/attendance`
/// (matches the web app's AttendanceRecord contract). Backend not live yet —
/// the History screen renders empty/error until it ships.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employee,
    this.role,
    this.checkIn,
    this.checkOut,
    required this.hours,
    required this.status,
    this.distanceKm = 0,
  });

  final String id;
  final String employee;
  final String? role;

  /// Pre-formatted local time (e.g. "09:02"), or null when there's no punch.
  final String? checkIn;
  final String? checkOut;
  final double hours;

  /// "present" | "late" | "absent" | "on-leave".
  final String status;
  final double distanceKm;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: (j['id'] ?? '').toString(),
        employee: j['employee'] as String? ?? '',
        role: j['role'] as String?,
        checkIn: j['checkIn'] as String?,
        checkOut: j['checkOut'] as String?,
        hours: (j['hours'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'present',
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
      );
}

/// One GPS sample along an employee's day (`GET /api/tracking/route`).
class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.speed,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? speed;

  factory RoutePoint.fromJson(Map<String, dynamic> j) => RoutePoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        timestamp: DateTime.parse(j['timestamp'] as String).toLocal(),
        speed: (j['speed'] as num?)?.toDouble(),
      );
}

/// An attendance punch with where/when it happened.
class CheckEvent {
  const CheckEvent({
    required this.lat,
    required this.lng,
    required this.time,
    this.place,
  });

  final double lat;
  final double lng;
  final DateTime time;
  final String? place;

  factory CheckEvent.fromJson(Map<String, dynamic> j) => CheckEvent(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        time: DateTime.parse(j['time'] as String).toLocal(),
        place: j['place'] as String?,
      );
}

/// A place where the employee was stationary for a while.
class RouteStop {
  const RouteStop({
    required this.id,
    required this.lat,
    required this.lng,
    this.label,
    required this.arrival,
    this.departure,
    this.duration,
  });

  final String id;
  final double lat;
  final double lng;
  final String? label;
  final DateTime arrival;
  final DateTime? departure;
  final String? duration;

  factory RouteStop.fromJson(Map<String, dynamic> j) => RouteStop(
        id: j['id'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        label: j['label'] as String?,
        arrival: DateTime.parse(j['arrival'] as String).toLocal(),
        departure: j['departure'] != null
            ? DateTime.parse(j['departure'] as String).toLocal()
            : null,
        duration: j['duration'] as String?,
      );
}

/// One employee's movement for a single day: GPS trail, stops and totals.
class RouteHistory {
  const RouteHistory({
    required this.employeeId,
    required this.date,
    required this.points,
    required this.stops,
    this.checkIn,
    this.checkOut,
    required this.distanceKm,
    this.duration,
  });

  final String employeeId;
  final String date;
  final List<RoutePoint> points;
  final List<RouteStop> stops;
  final CheckEvent? checkIn;
  final CheckEvent? checkOut;
  final double distanceKm;
  final String? duration;

  factory RouteHistory.fromJson(Map<String, dynamic> j) => RouteHistory(
        employeeId: j['employeeId'] as String? ?? '',
        date: j['date'] as String? ?? '',
        points: (j['points'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(RoutePoint.fromJson)
            .toList(),
        stops: (j['stops'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(RouteStop.fromJson)
            .toList(),
        checkIn: j['checkIn'] != null
            ? CheckEvent.fromJson(j['checkIn'] as Map<String, dynamic>)
            : null,
        checkOut: j['checkOut'] != null
            ? CheckEvent.fromJson(j['checkOut'] as Map<String, dynamic>)
            : null,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        duration: j['duration'] as String?,
      );
}
