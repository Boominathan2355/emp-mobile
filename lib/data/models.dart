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
