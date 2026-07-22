import '../data/api_client.dart';
import '../data/models.dart';

/// Attendance history for the History tab. Calls `GET /api/attendance`
/// (from/to = YYYY-MM-DD, inclusive) — the SAME contract the web app targets.
///
/// HEADS-UP: this endpoint is NOT implemented on the backend yet (there is no
/// attendance/punch-clock table; the tracking service only ingests raw GPS).
/// Until it ships, calls fail and the History screen shows its error/empty
/// state — no mock data, matching the web app's "real data only" policy.
class AttendanceService {
  final _api = ApiClient.instance;

  Future<List<AttendanceRecord>> history({String? from, String? to}) async {
    final params = <String, String>{
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final res = await _api.get<List<dynamic>>('/api/attendance$query');
    return res
        .cast<Map<String, dynamic>>()
        .map(AttendanceRecord.fromJson)
        .toList();
  }
}
