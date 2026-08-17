import '../data/api_client.dart';
import '../data/models.dart';

/// Route replay for one employee on one day.
/// Calls `GET /api/tracking/route?employee=<code>&date=YYYY-MM-DD`
/// (RouteController) — the same contract the web app targets.
class RouteService {
  final _api = ApiClient.instance;

  Future<RouteHistory> history({
    required String employeeId,
    required String date,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/tracking/route?employee=${Uri.encodeQueryComponent(employeeId)}'
      '&date=$date',
    );
    return RouteHistory.fromJson(res);
  }
}
